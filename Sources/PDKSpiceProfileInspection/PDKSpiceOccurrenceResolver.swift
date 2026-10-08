import CoreSpiceIO
import PDKCore
import PDKProfileAdmission

/// One ordered parse invocation owns acquisition provenance separately from content keys.
actor PDKSpiceOccurrenceResolver: SPICEContextualFileResolver {
    struct Entry: Sendable {
        let occurrence: SPICEParseOccurrenceID
        let input: PDKProfileSourceInput
        let document: SPICESourceDocument
        let diagnosticName: SPICEAccountedText
    }
    private let dependencies: any PDKProfileDependencyResolving
    private let bridge: PDKSpiceResourceBridge
    private let page: UInt64
    private let metadata: SPICESourceStorageReservation
    private var entries = SPICEAccountedCollection<Entry>(storageKind: .temporaryBytes)

    static func admit(dependencies: any PDKProfileDependencyResolving, bridge: PDKSpiceResourceBridge,
                      page: UInt64) throws -> Self {
        let metadata = try SPICESourceCapacity.reserve(of:
            ((any PDKProfileDependencyResolving), PDKSpiceResourceBridge, UInt64,
             SPICESourceStorageReservation, SPICEAccountedCollection<Entry>).self,
            capacity: 1, kind: .temporaryBytes, resources: bridge)
        return Self(dependencies: dependencies, bridge: bridge, page: page, metadata: metadata)
    }
    private init(dependencies: any PDKProfileDependencyResolving, bridge: PDKSpiceResourceBridge,
                 page: UInt64, metadata: SPICESourceStorageReservation) {
        self.dependencies = dependencies; self.bridge = bridge; self.page = page; self.metadata = metadata
    }
    func register(_ input: PDKProfileSourceInput) throws -> SPICESourceDocument {
        try bridge.checkCancellation()
        let occurrence = SPICEParseOccurrenceID(UInt64(entries.count))
        let nameCapacity = try bridge.reserveStorage(kind: .temporaryBytes, byteCount: 32)
        defer { withExtendedLifetime(nameCapacity) {} }
        let name = try SPICEAccountedText.copy("pdk-source-" + String(occurrence.rawValue), resources: bridge,
            maximumChunkByteCount: page)
        let binding = SPICEExactSourceBinding(key: input.sourceKey, reference: input.reference)
        let checked = try input.capture.withBytes { bytes in
            try SPICECheckedSource.admit(binding: binding, bytes: bytes, resources: bridge,
                maximumPageByteCount: page)
        }
        let document = try checked.document(expectedBinding: binding, occurrenceID: occurrence,
            resolvedPath: name.text).selectingLibrarySection(input.context.selectedSection, resources: bridge)
        try entries.append(.init(occurrence: occurrence, input: input, document: document,
            diagnosticName: name), resources: bridge)
        return document
    }
    func resolve(_ request: SPICESourceDependencyRequest) async throws -> SPICESourceDocument {
        let parent = try entry(request.parentOccurrenceID)
        guard try bridge.equal(parent.input.sourceKey, request.parentSourceKey),
              try optionalEqual(parent.input.context.selectedSection, request.parentSection) else {
            throw PDKProfileInspectionError.invalidFacts
        }
        let child = try await dependencies.resolve(.init(parent: parent.input,
            statementByteOffset: request.statementByteOffset, statementOrdinal: request.statementOrdinal,
            directiveKind: request.kind == .include ? "include" : "externalLibrary",
            literalRoute: request.literalRoute, selectedSection: request.requestedChildSection,
            preprocessingIdentity: request.environment.identity))
        try bridge.checkCancellation()
        guard try bridge.equal(child.context.preprocessingIdentity, request.environment.identity),
              try optionalEqual(child.context.selectedSection, request.requestedChildSection) else {
            throw PDKProfileInspectionError.invalidFacts
        }
        return try register(child)
    }
    func entry(_ occurrence: SPICEParseOccurrenceID) throws -> Entry {
        guard let index = Int(exactly: occurrence.rawValue), index >= 0, index < entries.count,
              entries[index].occurrence == occurrence else { throw PDKProfileInspectionError.invalidFacts }
        try bridge.charge(.tokens, units: 1); return entries[index]
    }
    func entry(file: String) throws -> Entry? {
        for value in entries { if try bridge.equal(value.diagnosticName.text, file) { return value } }
        return nil
    }
    func snapshot() -> SPICEAccountedCollection<Entry> { entries }
    private func optionalEqual(_ lhs: String?, _ rhs: String?) throws -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case (let lhs?, let rhs?): return try bridge.equal(lhs, rhs)
        default: return false
        }
    }
}
