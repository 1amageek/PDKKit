import CircuiteFoundation
import CoreSpiceIO
import PDKCore
import PDKProfileAdmission
import PDKSourceCapture

/// Ordered candidate state is isolated across source acquisition suspensions.
actor PDKSpiceCandidateResolver: SPICEContextualFileResolver {
    private struct Occurrence: Sendable {
        let id: SPICEParseOccurrenceID
        let parent: SPICEParseOccurrenceID?
        let bindingIndex: Int
        let sourceIndex: Int
        let logicalRoute: SPICEAccountedText
        let environment: SPICEPreprocessingEnvironment
        let document: SPICESourceDocument
        let diagnosticName: SPICEAccountedText
    }
    private let request: PDKSpiceCandidateDiscoveryRequest
    private let bridge: PDKSpiceResourceBridge
    private let page: UInt64
    private let discovery: any PDKLocalSourceDiscovering
    private let metadata: SPICESourceStorageReservation
    private var sources = SPICEAccountedCollection<PDKSpiceCandidateSource>(storageKind: .liveOwnedBytes)
    private var occurrences = SPICEAccountedCollection<Occurrence>(storageKind: .temporaryBytes)
    private var edges = SPICEAccountedCollection<PDKSourceDependency>(storageKind: .liveOwnedBytes)
    private var parsed = SPICEAccountedCollection<SPICEOwnedParseResult>(storageKind: .temporaryBytes)
    private var textOwners = SPICEAccountedCollection<SPICEAccountedText>(storageKind: .liveOwnedBytes)
    private var outputOwners = SPICEAccountedCollection<SPICESourceStorageReservation>(storageKind: .liveOwnedBytes)

    static func admit(request: PDKSpiceCandidateDiscoveryRequest, bridge: PDKSpiceResourceBridge,
                      page: UInt64, discovery: any PDKLocalSourceDiscovering) throws -> Self {
        let metadata = try SPICESourceCapacity.reserve(of: (
            PDKSpiceCandidateDiscoveryRequest, PDKSpiceResourceBridge, UInt64, (any PDKLocalSourceDiscovering),
            SPICESourceStorageReservation, SPICEAccountedCollection<PDKSpiceCandidateSource>,
            SPICEAccountedCollection<Occurrence>, SPICEAccountedCollection<PDKSourceDependency>,
            SPICEAccountedCollection<SPICEOwnedParseResult>, SPICEAccountedCollection<SPICEAccountedText>,
            SPICEAccountedCollection<SPICESourceStorageReservation>).self,
            capacity: 1, kind: .temporaryBytes, resources: bridge)
        return Self(request: request, bridge: bridge, page: page, discovery: discovery, metadata: metadata)
    }
    private init(request: PDKSpiceCandidateDiscoveryRequest, bridge: PDKSpiceResourceBridge,
                 page: UInt64, discovery: any PDKLocalSourceDiscovering, metadata: SPICESourceStorageReservation) {
        self.request = request; self.bridge = bridge; self.page = page; self.discovery = discovery; self.metadata = metadata
    }
    func validate() throws {
        guard !request.entries.isEmpty, !request.sources.isEmpty else { throw PDKSpiceCandidateDiscoveryError.invalidRequest }
        let routes = PDKSpiceCandidateRoutes(request: request, bridge: bridge)
        for index in request.roots.indices {
            for prior in request.roots.indices where prior < index {
                try bridge.charge(.tokens, units: 1)
                guard request.roots[index].rootID != request.roots[prior].rootID else {
                    throw PDKSpiceCandidateDiscoveryError.invalidRequest
                }
            }
        }
        for index in request.sources.indices {
            let binding = request.sources[index]
            guard !binding.sourceKey.isEmpty, !binding.logicalRoutes.isEmpty, binding.descriptor.format == .spice,
                  binding.descriptor.role == .input else {
                throw PDKSpiceCandidateDiscoveryError.invalidRequest
            }
            _ = try root(binding.rootID)
            for routeIndex in binding.logicalRoutes.indices {
                let route = binding.logicalRoutes[routeIndex]
                try routes.validateCanonical(route)
                for priorRoute in binding.logicalRoutes.indices where priorRoute < routeIndex {
                    if try bridge.equal(route, binding.logicalRoutes[priorRoute]) { throw PDKSpiceCandidateDiscoveryError.ambiguousRoute }
                }
                for prior in request.sources.indices where prior < index {
                    for known in request.sources[prior].logicalRoutes {
                        if try bridge.equal(route, known) { throw PDKSpiceCandidateDiscoveryError.ambiguousRoute }
                    }
                }
            }
            for prior in request.sources.indices where prior < index {
                let known = request.sources[prior]
                if try bridge.equal(binding.sourceKey, known.sourceKey) {
                    guard binding.rootID == known.rootID, binding.relativePath == known.relativePath,
                          binding.budget == known.budget,
                          try descriptor(binding.descriptor, equals: known.descriptor),
                          try optionalEqual(binding.assetID, known.assetID) else {
                        throw PDKSpiceCandidateDiscoveryError.invalidRequest
                    }
                }
            }
        }
        for index in request.orderedSearchRoutes.indices {
            let search = request.orderedSearchRoutes[index]
            try routes.validateCanonical(search)
            for prior in request.orderedSearchRoutes.indices where prior < index {
                if try bridge.equal(search, request.orderedSearchRoutes[prior]) { throw PDKSpiceCandidateDiscoveryError.invalidRequest }
            }
        }
        for entry in request.entries {
            try routes.validateCanonical(entry.logicalRoute)
            guard let binding = try routes.match(entry.logicalRoute),
                  try bridge.equal(request.sources[binding].sourceKey, entry.sourceKey) else {
                throw PDKSpiceCandidateDiscoveryError.missingRoute
            }
        }
    }
    func root(_ entry: PDKSpiceCandidateEntry, environment: SPICEPreprocessingEnvironment) async throws -> SPICESourceDocument {
        let routes = PDKSpiceCandidateRoutes(request: request, bridge: bridge)
        guard let binding = try routes.match(entry.logicalRoute),
              try bridge.equal(request.sources[binding].sourceKey, entry.sourceKey) else {
            throw PDKSpiceCandidateDiscoveryError.missingRoute
        }
        let depth = try bridge.reservePDK(.includeDepth, 1)
        defer { withExtendedLifetime(depth) {} }
        try bridge.chargePDK(.contextualNodes); try bridge.chargePDK(.expansions)
        let source = try await acquire(binding)
        return try register(binding: binding, source: source, route: entry.logicalRoute,
            section: entry.selectedSection, environment: environment, parent: nil)
    }
    func resolve(_ request: SPICESourceDependencyRequest) async throws -> SPICESourceDocument {
        let parent = try occurrence(request.parentOccurrenceID)
        guard try bridge.equal(self.request.sources[parent.bindingIndex].sourceKey, request.parentSourceKey),
              try optionalEqual(parent.document.librarySection, request.parentSection) else {
            throw PDKSpiceCandidateDiscoveryError.invalidRequest
        }
        let routes = PDKSpiceCandidateRoutes(request: self.request, bridge: bridge)
        let selected = try routes.child(parentRoute: parent.logicalRoute.text, literal: request.literalRoute)
        try checkCycle(binding: selected.0, section: request.requestedChildSection,
            environment: request.environment.identity, parent: parent)
        var depth: UInt64 = 2
        var ancestor = parent.parent
        while let id = ancestor {
            let entry = try occurrence(id)
            let (next, overflow) = depth.addingReportingOverflow(1)
            guard !overflow else { throw SPICESourceStorageError.arithmeticOverflow }; depth = next
            ancestor = entry.parent
        }
        let depthOwner = try bridge.reservePDK(.includeDepth, depth)
        defer { withExtendedLifetime(depthOwner) {} }
        try bridge.chargePDK(.contextualNodes); try bridge.chargePDK(.dependencyEdges); try bridge.chargePDK(.expansions)
        let source = try await acquire(selected.0)
        let parentSource = sources[parent.sourceIndex], childSource = sources[source]
        let literal = try text(request.literalRoute)
        let section: String?
        if let observed = request.requestedChildSection { section = try text(observed) } else { section = nil }
        let environment = try text(request.environment.identity)
        let (lexicalOrder, overflow) = UInt64(edges.count).addingReportingOverflow(1)
        guard !overflow else { throw SPICESourceStorageError.arithmeticOverflow }
        let edge = try PDKSourceDependency(parentSourceKey: parentSource.source.sourceKey,
            parentReference: parentSource.capture.reference, statementByteOffset: request.statementByteOffset,
            statementOrdinal: request.statementOrdinal, directiveKind: request.kind == .include ? "include" : "externalLibrary",
            literalRoute: literal, childSourceKey: childSource.source.sourceKey, childReference: childSource.capture.reference,
            selectedSection: section, preprocessingIdentity: environment, lexicalOrder: lexicalOrder, resources: bridge.resources)
        try edges.append(edge, resources: bridge)
        return try register(binding: selected.0, source: source, route: selected.1.text,
            section: request.requestedChildSection, environment: request.environment, parent: parent.id)
    }
    func record(_ result: SPICEOwnedParseResult) throws { try parsed.append(result, resources: bridge) }
    func sourceKey(file: String) throws -> String? {
        for entry in occurrences {
            if try bridge.equal(entry.diagnosticName.text, file) { return sources[entry.sourceIndex].source.sourceKey }
        }
        return nil
    }
    private func occurrence(_ id: SPICEParseOccurrenceID) throws -> Occurrence {
        try bridge.charge(.tokens, units: 1)
        guard let index = Int(exactly: id.rawValue), index < occurrences.count, index >= 0,
              occurrences[index].id == id else { throw PDKSpiceCandidateDiscoveryError.invalidRequest }
        return occurrences[index]
    }
    private func checkCycle(binding: Int, section: String?, environment: String, parent: Occurrence) throws {
        var current: Occurrence? = parent
        while let ancestor = current {
            if try bridge.equal(request.sources[binding].sourceKey, request.sources[ancestor.bindingIndex].sourceKey),
               try optionalEqual(section, ancestor.document.librarySection),
               try bridge.equal(environment, ancestor.environment.identity) {
                throw PDKSpiceCandidateDiscoveryError.contextualCycle
            }
            if let id = ancestor.parent { current = try occurrence(id) } else { current = nil }
        }
    }
    private func root(_ id: ArtifactRootID) throws -> PDKProfileAuthorizedRoot {
        for root in request.roots { try bridge.charge(.tokens, units: 1); if root.rootID == id { return root } }
        throw PDKSpiceCandidateDiscoveryError.invalidRequest
    }
    private func acquire(_ bindingIndex: Int) async throws -> Int {
        let binding = request.sources[bindingIndex]
        for index in sources.indices {
            if try bridge.equal(sources[index].source.sourceKey, binding.sourceKey) { return index }
        }
        let authorized = try root(binding.rootID)
        try bridge.chargePDK(.uniqueSources)
        let observed = try await discovery.discover(descriptor: binding.descriptor,
            rootURL: authorized.rootURL, rootID: authorized.rootID, relativePath: binding.relativePath,
            budget: binding.budget, resources: bridge.resources)
        guard try descriptor(observed.reference.descriptor, equals: binding.descriptor) else {
            throw PDKSpiceCandidateDiscoveryError.invalidRequest
        }
        guard observed.reference.digest.algorithm == .sha256 else { throw PDKSpiceCandidateDiscoveryError.invalidRequest }
        let digestText = try text(observed.reference.digest.hexadecimalValue)
        let digestOwner = try bridge.reserveStorage(kind: .liveOwnedBytes, byteCount: 64)
        try outputOwners.append(digestOwner, resources: bridge)
        let digest = try ContentDigest(algorithm: .sha256, hexadecimalValue: digestText)
        let kind = try ArtifactKind(rawValue: text(observed.reference.descriptor.kind.rawValue))
        let reference = try ArtifactReference(digest: digest, byteCount: observed.reference.byteCount,
            descriptor: .init(role: .input, kind: kind, format: .spice))
        let capture = try observed.rebinding(reference: reference, resources: bridge.resources)
        let key = try text(binding.sourceKey), assetID: String?
        if let asset = binding.assetID { assetID = try text(asset) } else { assetID = nil }
        var routes = SPICEAccountedCollection<String>(storageKind: .liveOwnedBytes)
        for alias in request.sources {
            guard try bridge.equal(alias.sourceKey, binding.sourceKey) else { continue }
            for route in alias.logicalRoutes { try routes.append(text(route), resources: bridge) }
        }
        let raw = try array(routes)
        let source = try PDKProfileSource(sourceKey: key, assetID: assetID, reference: capture.reference,
            logicalRoutes: raw, resources: bridge.resources)
        let index = sources.count
        try sources.append(.init(source: source, capture: capture), resources: bridge)
        return index
    }
    private func register(binding: Int, source: Int, route: String, section: String?,
                          environment: SPICEPreprocessingEnvironment, parent: SPICEParseOccurrenceID?) throws -> SPICESourceDocument {
        let id = SPICEParseOccurrenceID(UInt64(occurrences.count))
        let nameCapacity = try bridge.reserveStorage(kind: .temporaryBytes, byteCount: 40)
        defer { withExtendedLifetime(nameCapacity) {} }
        let name = try SPICEAccountedText.copy("pdk-candidate-" + String(id.rawValue), resources: bridge, maximumChunkByteCount: page)
        let sourceBinding = SPICEExactSourceBinding(key: sources[source].source.sourceKey, reference: sources[source].capture.reference)
        let checked = try sources[source].capture.withBytes { bytes in
            try SPICECheckedSource.admit(binding: sourceBinding, bytes: bytes, resources: bridge, maximumPageByteCount: page)
        }
        let document = try checked.document(expectedBinding: sourceBinding, occurrenceID: id,
            resolvedPath: name.text).selectingLibrarySection(section, resources: bridge)
        let ownedRoute = try SPICEAccountedText.copy(route, resources: bridge, maximumChunkByteCount: page)
        try occurrences.append(.init(id: id, parent: parent, bindingIndex: binding, sourceIndex: source,
            logicalRoute: ownedRoute, environment: environment, document: document, diagnosticName: name), resources: bridge)
        return document
    }
    private func text(_ original: String) throws -> String {
        let owner = try SPICEAccountedText.copy(original, resources: bridge, maximumChunkByteCount: page)
        try textOwners.append(owner, resources: bridge); return owner.text
    }
    private func array<Element: Sendable>(_ values: SPICEAccountedCollection<Element>) throws -> [Element] {
        let owner = try SPICESourceCapacity.reserve(of: Element.self, capacity: values.count,
            kind: .liveOwnedBytes, resources: bridge)
        try outputOwners.append(owner, resources: bridge)
        var output: [Element] = []; output.reserveCapacity(values.count)
        for value in values { try bridge.charge(.retainedElements, units: 1); output.append(value) }
        return output
    }
    private func optionalEqual(_ lhs: String?, _ rhs: String?) throws -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case (let lhs?, let rhs?): try bridge.equal(lhs, rhs)
        default: false
        }
    }
    private func descriptor(_ lhs: ArtifactDescriptor, equals rhs: ArtifactDescriptor) throws -> Bool {
        try bridge.equal(lhs.role.rawValue, rhs.role.rawValue) && bridge.equal(lhs.kind.rawValue, rhs.kind.rawValue) &&
            bridge.equal(lhs.format.rawValue, rhs.format.rawValue)
    }
    func publish(environment: SPICEPreprocessingEnvironment, policyIdentity: String) throws -> PDKSpiceCandidateGraph {
        var coverage = SPICEAccountedCollection<PDKSpiceCandidateOccurrence>(storageKind: .liveOwnedBytes)
        for entry in occurrences {
            var inactive = SPICEAccountedCollection<UInt64>(storageKind: .liveOwnedBytes)
            for result in parsed {
                for event in result.netlist.preprocessingEvents {
                    try bridge.charge(.tokens, units: 1)
                    guard let location = event.location,
                          try bridge.equal(location.file, entry.diagnosticName.text) else { continue }
                    guard event.selection != .unresolved else { throw PDKSpiceCandidateDiscoveryError.unsupportedSemantics }
                    if event.selection == .inactive {
                        try inactive.append(entry.document.originalByteOffset(at: location, resources: bridge), resources: bridge)
                    }
                }
            }
            let section: String?
            if let original = entry.document.librarySection { section = try text(original) } else { section = nil }
            try coverage.append(.init(occurrenceID: entry.id.rawValue, parentOccurrenceID: entry.parent?.rawValue,
                sourceKey: sources[entry.sourceIndex].source.sourceKey, logicalRoute: try text(entry.logicalRoute.text),
                selectedSection: section, preprocessingIdentity: try text(entry.environment.identity),
                inactiveStatementOffsets: try array(inactive)), resources: bridge)
        }
        let sourceValues = try array(sources), dependencies = try array(edges), occurrenceValues = try array(coverage)
        let policy = try text(policyIdentity), initial = try text(environment.identity)
        try bridge.checkCancellation()
        return .init(policyIdentity: policy, initialPreprocessingIdentity: initial, sources: sourceValues,
            dependencies: dependencies, occurrences: occurrenceValues, retaining: (sources, edges, coverage, textOwners, outputOwners))
    }
}
