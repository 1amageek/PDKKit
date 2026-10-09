import CircuiteFoundation
import Foundation
import PDKCore
@testable import PDKProfileAdmission
import PDKSourceCapture

/// Real file capture/admission with an explicit controlled graph provider, not domain qualification.
struct ExecutionBindingFixture {
    let fixture: AdmissionFixture
    let profile: AdmittedPDKProfile
    let projection: PDKStageProjection
    let observed: PDKExecutionSourceObservation
    let claim: PDKExecutionConsumptionClaim
    let resources: LocalPDKAdmissionResources

    static func make(graph: AdmissionFixture.Graph = .leaf, external: Bool = true, corner: Bool = false) async throws -> Self {
        let fixture = try await AdmissionFixture.make(graph: graph, support: true, corner: corner)
        let profile = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: fixture.definition.dependencies).registration()]).admit(fixture.request)
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget)
        let requirement = try PDKConsumerRequirement(stageID: "native.stage", requirementIDs: ["simulation"],
            cornerIDs: corner ? ["tt"] : [], configurationIdentity: "actual.config.v1")
        let projection = try projectPDKProfile(profile, for: requirement, resources: resources)
        var observed: [PDKConsumedSource] = []
        var incoming: PDKSourceDependency?
        if external {
            let bytes = Data("* actual circuit\n.include root.sp\n.end\n".utf8)
            try bytes.write(to: fixture.root.appending(path: "circuit.sp"))
            let binding = fixture.request.sources[0]
            let reference = try await LocalPDKBoundedSourceCapturer().discover(
                descriptor: ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: "spice.circuit"), format: .spice),
                rootURL: fixture.root, rootID: binding.rootID, relativePath: ArtifactRelativePath(segments: ["circuit.sp"]),
                budget: binding.budget, resources: resources).reference
            observed.append(try PDKConsumedSource(occurrenceID: 40, sourceKey: "circuit", reference: reference,
                cornerID: nil, selectedSection: nil, preprocessingIdentity: "environment.empty.v1", parentOccurrenceID: nil, incomingDependency: nil))
            incoming = try .init(parentSourceKey: "circuit", parentReference: reference, statementByteOffset: 17,
                statementOrdinal: 1, directiveKind: "include", literalRoute: "root.sp", childSourceKey: "root",
                childReference: fixture.rootReference, selectedSection: nil, preprocessingIdentity: "environment.empty.v1", lexicalOrder: 0)
        }
        let rootID: UInt64 = external ? 41 : 40
        observed.append(try PDKConsumedSource(occurrenceID: rootID, sourceKey: "root", reference: fixture.rootReference,
            cornerID: corner ? "tt" : nil, selectedSection: nil, preprocessingIdentity: fixture.definition.initialPreprocessingIdentity,
            parentOccurrenceID: external ? 40 : nil, incomingDependency: incoming))
        for (index, edge) in fixture.definition.dependencies.enumerated() {
            observed.append(try PDKConsumedSource(occurrenceID: rootID + UInt64(index) + 1, sourceKey: edge.childSourceKey,
                reference: edge.childReference, cornerID: corner ? "tt" : nil, selectedSection: edge.selectedSection,
                preprocessingIdentity: edge.preprocessingIdentity, parentOccurrenceID: rootID, incomingDependency: edge))
        }
        // The controlled provider binds actual captured graph inputs, not diagnostic availability.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let graphBytes = try encoder.encode(observed)
        let input = try PDKProfileCanonicalEncoding().digest(Array(graphBytes) + Array(requirement.configurationIdentity.utf8) + Array("controlled.graph.v1".utf8))
        let observation = try PDKExecutionSourceObservation(executionInputIdentity: input, configurationIdentity: requirement.configurationIdentity,
            grammarPolicyIdentity: "controlled.graph.v1", sources: observed)
        let bindings = try observed.dropFirst(external ? 1 : 0).enumerated().map { try PDKExecutionSourceBinding(profileOccurrenceID: UInt64($0.offset), executionOccurrenceID: $0.element.occurrenceID) }
        let entry = try PDKExecutionEntry(profileRootOccurrenceID: 0, executionRootOccurrenceID: rootID,
            externalParentOccurrenceID: external ? 40 : nil, externalParentReference: external ? observed[0].reference : nil,
            incomingDependency: incoming)
        let scopedSources = try observed.dropFirst(external ? 1 : 0).enumerated().map { index, source in
            try PDKConsumedSource(occurrenceID: UInt64(index), sourceKey: source.sourceKey, reference: source.reference,
                cornerID: source.cornerID, selectedSection: source.selectedSection, preprocessingIdentity: source.preprocessingIdentity,
                parentOccurrenceID: index == 0 ? nil : 0, incomingDependency: index == 0 ? nil : source.incomingDependency)
        }
        let scoped = try PDKConsumptionClaim(stageRequirement: requirement, profileIdentity: profile.claim.semanticSelectionDigest,
            expectedProjectionIdentity: projection.identity, actualSources: scopedSources, actualMappings: Array(projection.knownMappings),
            actualCorners: Array(projection.corners), actualSelections: Array(projection.selections), domainEvidenceReference: observed[0].reference)
        let claim = try PDKExecutionConsumptionClaim(scopedClaim: scoped, executionInputIdentity: input, sourceBindings: bindings, entries: [entry])
        return .init(fixture: fixture, profile: profile, projection: projection, observed: observation, claim: claim, resources: resources)
    }
    func cleanup() { resources.close(); fixture.cleanup() }
    func observation(sources: [PDKConsumedSource]? = nil, input: ContentDigest? = nil, configuration: String? = nil) throws -> PDKExecutionSourceObservation {
        try .init(executionInputIdentity: input ?? observed.executionInputIdentity,
            configurationIdentity: configuration ?? observed.configurationIdentity, grammarPolicyIdentity: observed.grammarPolicyIdentity,
            sources: sources ?? observed.sources)
    }
    func claim(entries: [PDKExecutionEntry]? = nil, bindings: [PDKExecutionSourceBinding]? = nil, input: ContentDigest? = nil) throws -> PDKExecutionConsumptionClaim {
        try .init(scopedClaim: claim.scopedClaim, executionInputIdentity: input ?? claim.executionInputIdentity,
            sourceBindings: bindings ?? claim.sourceBindings, entries: entries ?? claim.entries)
    }
    func match(_ claim: PDKExecutionConsumptionClaim? = nil, _ observation: PDKExecutionSourceObservation? = nil,
               resources: (any PDKAdmissionResourceAccounting)? = nil) throws -> PDKMatchedExecutionConsumption {
        try matchPDKExecutionConsumption(claim ?? self.claim, against: projection, observed: observation ?? observed, resources: resources ?? self.resources)
    }
}
