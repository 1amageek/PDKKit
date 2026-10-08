import CircuiteFoundation
import PDKCore
import PDKSourceCapture

actor PDKProfileInvocationResolver: PDKProfileDependencyResolving {
    private struct Node: Sendable {
        let context: PDKProfileSourceContext
        var input: PDKProfileSourceInput?
    }
    private let authority: PDKProfileInputAuthority
    private let availability: PDKProfileAvailability
    private let registry: PDKProfileSourceRegistry
    private let expected: [PDKSourceDependency]
    private let work: PDKAdmissionWork
    private var nodes = PDKAdmissionCollection<Node>()
    private var events = PDKAdmissionCollection<PDKProfileDependencyEvent>()
    private var failure: PDKProfileAdmissionError?
    private var nextExpected = 0
    private var frozen = false
    init(authority: PDKProfileInputAuthority, availability: PDKProfileAvailability,
         registry: PDKProfileSourceRegistry, expected: [PDKSourceDependency]) {
        self.authority = authority; self.availability = availability; self.registry = registry
        self.expected = expected; work = availability.work
    }
    func root(source: PDKProfileSource, context: PDKProfileSourceContext)
        async throws(PDKProfileAdmissionError) -> PDKProfileSourceInput {
        try ready()
        let binding = try availability.source(source), root = try availability.root(binding.rootID)
        try work.charge(.contextualNodes); try work.charge(.expansions)
        let depth = try work.reserve(.includeDepth, 1)
        defer { withExtendedLifetime(depth) {} }
        let nodeID = nodes.count
        try nodes.append(Node(context: context, input: nil), work: work)
        let capture = try await registry.acquire(reference: source.reference, rootURL: root.rootURL,
            rootID: binding.rootID, relativePath: binding.relativePath, budget: binding.budget)
        let input = PDKProfileSourceInput(context: context, capture: capture, logicalRoute: binding.logicalRoute,
            incomingEvent: nil, authority: authority, ancestry: .init(), nodeID: nodeID)
        nodes.complete(at: nodeID, with: Node(context: context, input: input))
        try work.check(); return input
    }
    func resolve(_ request: PDKProfileDependencyRequest) async throws(PDKProfileAdmissionError) -> PDKProfileSourceInput {
        do { return try await resolveChecked(request) }
        catch { if failure == nil { failure = error }; throw error }
    }
    private func resolveChecked(_ request: PDKProfileDependencyRequest)
        async throws(PDKProfileAdmissionError) -> PDKProfileSourceInput {
        try ready(); try validate(request.parent)
        guard request.statementByteOffset < request.parent.reference.byteCount,
              nextExpected < expected.count else { throw .dependencyDrift }
        let edge = expected[nextExpected]
        guard edge.statementByteOffset == request.statementByteOffset, edge.statementOrdinal == request.statementOrdinal,
              try work.equal(edge.parentSourceKey, request.parent.sourceKey),
              try work.equal(edge.parentReference, request.parent.reference),
              try work.equal(edge.directiveKind, request.directiveKind), try work.equal(edge.literalRoute, request.literalRoute),
              try work.equal(edge.selectedSection, request.selectedSection),
              try work.equal(edge.preprocessingIdentity, request.preprocessingIdentity) else { throw .dependencyDrift }
        let resolved = try PDKProfileRouteResolution(definition: authority.definition.value, work: work)
            .child(parentRoute: request.parent.logicalRoute, literal: request.literalRoute)
        guard try work.equal(resolved.0.sourceKey, edge.childSourceKey),
              try work.equal(resolved.0.reference, edge.childReference) else { throw .dependencyDrift }
        let context = PDKProfileSourceContext(sourceKey: edge.childSourceKey, selectedSection: edge.selectedSection,
            preprocessingIdentity: edge.preprocessingIdentity, cornerID: request.parent.context.cornerID)
        if try work.equal(context, request.parent.context) { throw .contextualCycle }
        for ancestor in request.parent.ancestry {
            if try work.equal(context, ancestor) { throw .contextualCycle }
        }
        let binding = try availability.source(resolved.0), root = try availability.root(binding.rootID)
        try work.charge(.dependencyEdges); try work.charge(.contextualNodes); try work.charge(.expansions)
        let (depthCount, overflow) = request.parent.ancestry.count.addingReportingOverflow(2)
        guard !overflow else { throw .resource(.arithmeticOverflow(.includeDepth)) }
        let depth = try work.reserve(.includeDepth, UInt64(depthCount))
        defer { withExtendedLifetime(depth) {} }
        var ancestry = PDKAdmissionCollection<PDKProfileSourceContext>()
        for ancestor in request.parent.ancestry { try ancestry.append(ancestor, work: work) }
        try ancestry.append(request.parent.context, work: work)
        let childID = nodes.count
        let event = PDKProfileDependencyEvent(edge: edge, parent: request.parent.context, child: context,
            parentNodeID: request.parent.nodeID, childNodeID: childID)
        try nodes.append(Node(context: context, input: nil), work: work)
        try events.append(event, work: work); nextExpected += 1
        // Authorization and occurrence insertion precede acquisition suspension.
        let capture = try await registry.acquire(reference: edge.childReference, rootURL: root.rootURL,
            rootID: binding.rootID, relativePath: binding.relativePath, budget: binding.budget)
        let input = PDKProfileSourceInput(context: context, capture: capture, logicalRoute: resolved.1,
            incomingEvent: event, authority: authority, ancestry: ancestry, nodeID: childID)
        nodes.complete(at: childID, with: Node(context: context, input: input))
        try work.check(); return input
    }
    func checkFailure() throws(PDKProfileAdmissionError) { try ready() }
    func eventCount() -> Int { events.count }
    func validateFacts(_ facts: PDKProfileSourceFacts, root: PDKProfileSourceInput, firstEvent: Int)
        throws(PDKProfileAdmissionError) {
        try ready(); try validate(root); try validate(facts.input)
        guard facts.input.nodeID == root.nodeID else { throw .providerIdentity }
        guard facts.unsupportedFactKinds.isEmpty, facts.lostFactKinds.isEmpty else { throw .unsupportedSemantics }
        guard facts.events.count == events.count - firstEvent else { throw .dependencyDrift }
        for index in facts.events.indices { try sameEvent(facts.events[index], events[firstEvent + index]) }
        for index in root.nodeID..<nodes.count {
            try work.step()
            guard let input = nodes[index].input else { throw .missingCoverage }
            var found: PDKProfileSourceCoverage?
            for coverage in facts.coverage {
                try work.step()
                if coverage.input.nodeID == index {
                    guard found == nil else { throw .missingCoverage }; found = coverage
                }
            }
            guard let coverage = found else { throw .missingCoverage }
            try validate(coverage.input)
            guard try work.equal(coverage.observedSection, input.context.selectedSection),
                  !coverage.evidenceIdentity.isEmpty else { throw .missingCoverage }
            var cursor = 0
            for event in events {
                try work.step(); guard event.parentNodeID == index else { continue }
                guard cursor < coverage.activeDependencies.count else { throw .missingCoverage }
                try sameEvent(coverage.activeDependencies[cursor], event); cursor += 1
            }
            guard cursor == coverage.activeDependencies.count else { throw .missingCoverage }
            if case .leaf = coverage.meaning {
                guard cursor == 0, coverage.inactiveStatementOffsets.isEmpty else { throw .missingCoverage }
            }
            for offset in coverage.inactiveStatementOffsets { try work.step(); guard offset < input.reference.byteCount else { throw .missingCoverage } }
        }
        guard facts.coverage.count == nodes.count - root.nodeID else { throw .missingCoverage }
        for mapping in facts.mappings {
            try validate(mapping.input)
            guard mapping.input.nodeID >= root.nodeID, !mapping.factKind.isEmpty, !mapping.name.isEmpty else { throw .providerIdentity }
        }
        for fact in facts.pvt { try knownReference(fact.sourceReference, starting: root.nodeID) }
        for fact in facts.temperatures { try knownReference(fact.sourceReference, starting: root.nodeID) }
    }
    func freeze() throws(PDKProfileAdmissionError)
        -> (PDKAdmissionCollection<PDKProfileSourceInput>, PDKAdmissionCollection<PDKProfileDependencyEvent>) {
        try ready()
        guard nextExpected == expected.count else { throw .dependencyDrift }
        var inputs = PDKAdmissionCollection<PDKProfileSourceInput>()
        for node in nodes { try work.step(); guard let input = node.input else { throw .missingCoverage }; try inputs.append(input, work: work) }
        frozen = true
        return (inputs, events)
    }
    private func ready() throws(PDKProfileAdmissionError) {
        try work.check()
        if let failure { throw failure }
        guard !frozen else { throw .resource(.closed) }
    }
    private func validate(_ input: PDKProfileSourceInput) throws(PDKProfileAdmissionError) {
        try work.step()
        guard input.authority === authority, input.nodeID >= 0, input.nodeID < nodes.count,
              let known = nodes[input.nodeID].input,
              try work.equal(input.context, known.context), try work.equal(input.reference, known.reference),
              try work.equal(input.logicalRoute, known.logicalRoute) else { throw .providerIdentity }
    }
    private func knownReference(_ reference: CircuiteFoundation.ArtifactReference, starting: Int) throws(PDKProfileAdmissionError) {
        for index in starting..<nodes.count {
            try work.step()
            if let input = nodes[index].input, try work.equal(reference, input.reference) { return }
        }
        throw .providerIdentity
    }
    private func sameEvent(_ lhs: PDKProfileDependencyEvent, _ rhs: PDKProfileDependencyEvent) throws(PDKProfileAdmissionError) {
        try work.step()
        guard lhs.parentNodeID == rhs.parentNodeID, lhs.childNodeID == rhs.childNodeID,
              try work.equal(lhs.parentContext, rhs.parentContext), try work.equal(lhs.childContext, rhs.childContext),
              try work.equal(lhs.edge, rhs.edge) else { throw .dependencyDrift }
    }
}
