import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import PDKCore
@testable import PDKProfileAdmission
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ConsumptionTests {
    @Test func explicitSubsetKeepsUnrelatedMandatorySupportInTheParent() async throws {
        let fixture = try await AdmissionFixture.make(support: true, alias: true); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        #expect(projection.sources.count == 1)
        #expect(projection.sources[0].sourceKey == "root")
        #expect(projection.profile.claim.mandatorySupportSourceKeys == ["support"])
        #expect(projection.profile.sourceInputs.count == 3)
        let result = try matchPDKConsumption(claim(projection), against: projection, resources: resources)
        #expect(result.domainEvidenceReference == fixture.rootReference)
        #expect(result.projection.identity == projection.identity)
    }
    @Test func unknownRequirementsAndImplicitOrUnusedCornersFail() async throws {
        let fixture = try await ConsumptionFixture.make(.multiCorner); defer { fixture.cleanup() }
        let profile = try await fixture.admit()
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        for requirement in [try stage(requirements: ["unknown"], corners: ["tt"]),
                            try stage(corners: []), try stage(corners: ["foreign"])] {
            #expect(throws: PDKProfileConsumptionError.invalidStageSubset) { try projectPDKProfile(profile, for: requirement, resources: resources) }
        }
        let projection = try projectPDKProfile(profile, for: stage(corners: ["tt"]), resources: resources)
        #expect(projection.corners.count == 1)
        #expect(projection.sources.count == 2)
        #expect(projection.sources[1].cornerID == "tt")
    }
    @Test func repeatedClosurePreservesDistinctOccurrencesAndRejectsMissingOrExtraSources() async throws {
        let fixture = try await AdmissionFixture.make(graph: .repeated, support: true); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        #expect(projection.sources.count == 3)
        #expect(projection.sources[1].parentOccurrenceID == 0)
        #expect(projection.sources[2].parentOccurrenceID == 0)
        #expect(projection.sources[1].incomingDependency?.lexicalOrder == 1)
        #expect(projection.sources[2].incomingDependency?.lexicalOrder == 2)
        _ = try matchPDKConsumption(claim(projection), against: projection, resources: resources)
        #expect(throws: PDKProfileConsumptionError.sourceMismatch(2)) {
            try matchPDKConsumption(claim(projection, sources: Array(projection.sources.prefix(2))), against: projection, resources: resources)
        }
        let support = try #require(profile.sourceInputs.first { $0.sourceKey == "support" })
        let extra = try PDKConsumedSource(occurrenceID: 3, sourceKey: support.sourceKey, reference: support.reference,
            cornerID: nil, selectedSection: nil, preprocessingIdentity: support.context.preprocessingIdentity,
            parentOccurrenceID: nil, incomingDependency: nil)
        #expect(throws: PDKProfileConsumptionError.sourceMismatch(3)) {
            try matchPDKConsumption(claim(projection, sources: Array(projection.sources) + [extra]), against: projection, resources: resources)
        }
    }
    @Test func reorderedRepeatedIncludesCannotHideBehindTheSameUniqueSourceSet() async throws {
        let fixture = try await AdmissionFixture.make(graph: .repeated); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        let sources = [projection.sources[0], try source(projection.sources[2], id: 1), try source(projection.sources[1], id: 2)]
        #expect(throws: PDKProfileConsumptionError.sourceMismatch(1)) {
            try matchPDKConsumption(claim(projection, sources: sources), against: projection, resources: resources)
        }
        let child = projection.sources[2]
        let original = try #require(child.incomingDependency)
        let wrongEdge = try PDKSourceDependency(parentSourceKey: projection.sources[1].sourceKey,
            parentReference: projection.sources[1].reference, statementByteOffset: original.statementByteOffset,
            statementOrdinal: original.statementOrdinal, directiveKind: original.directiveKind, literalRoute: original.literalRoute,
            childSourceKey: child.sourceKey, childReference: child.reference, selectedSection: child.selectedSection,
            preprocessingIdentity: child.preprocessingIdentity, lexicalOrder: original.lexicalOrder)
        let wrongParent = try PDKConsumedSource(occurrenceID: 2, sourceKey: child.sourceKey, reference: child.reference,
            cornerID: child.cornerID, selectedSection: child.selectedSection, preprocessingIdentity: child.preprocessingIdentity,
            parentOccurrenceID: 1, incomingDependency: wrongEdge)
        #expect(throws: PDKProfileConsumptionError.sourceMismatch(2)) {
            try matchPDKConsumption(claim(projection, sources: [projection.sources[0], projection.sources[1], wrongParent]),
                against: projection, resources: resources)
        }
    }
    @Test func eachCornerMustConsumeItsOwnChildOccurrence() async throws {
        let fixture = try await ConsumptionFixture.make(.multiCorner); defer { fixture.cleanup() }
        let profile = try await fixture.admit()
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(corners: ["tt", "ss"]), resources: resources)
        #expect(projection.sources.count == 4)
        #expect(projection.sources[1].sourceKey == projection.sources[3].sourceKey)
        #expect(projection.sources[1].cornerID == "ss")
        #expect(projection.sources[3].cornerID == "tt")
        #expect(projection.sources[3].parentOccurrenceID == 2)
        _ = try matchPDKConsumption(claim(projection), against: projection, resources: resources)
        #expect(throws: PDKProfileConsumptionError.sourceMismatch(3)) {
            try matchPDKConsumption(claim(projection, sources: Array(projection.sources.prefix(3))), against: projection, resources: resources)
        }
    }
    @Test func fullDescriptorSectionAndPreprocessingAreCompared() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        let original = projection.sources[0]
        let changed = ArtifactReference(id: original.reference.id,
            descriptor: .init(role: .output, kind: original.reference.descriptor.kind, format: original.reference.descriptor.format))
        for source in [try self.source(original, reference: changed), try self.source(original, section: "wrong"),
                       try self.source(original, preprocessing: "wrong")] {
            #expect(throws: PDKProfileConsumptionError.sourceMismatch(0)) {
                try matchPDKConsumption(claim(projection, sources: [source]), against: projection, resources: resources)
            }
        }
    }
    @Test func stageConfigurationAndParentAndProjectionIdentitiesMustMatch() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        #expect(throws: PDKProfileConsumptionError.stageMismatch) {
            try matchPDKConsumption(claim(projection, requirement: stage(config: "different")), against: projection, resources: resources)
        }
        let foreign = try ContentDigest(algorithm: .sha256, hexadecimalValue: String(repeating: "0", count: 64))
        #expect(throws: PDKProfileConsumptionError.profileMismatch) {
            try matchPDKConsumption(claim(projection, profile: foreign), against: projection, resources: resources)
        }
        #expect(throws: PDKProfileConsumptionError.projectionMismatch) {
            try matchPDKConsumption(claim(projection, identity: foreign), against: projection, resources: resources)
        }
    }
    @Test func actualPVTAndSelectionCannotBeReplacedByCorrectSourceDigests() async throws {
        let fixture = try await ConsumptionFixture.make(.multiCorner); defer { fixture.cleanup() }
        let profile = try await fixture.admit()
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(corners: ["tt"]), resources: resources)
        var pvt = projection.corners[0].pvt; pvt.temperatureCelsius += 1
        let corner = try PDKProfileCorner(cornerID: "tt", pvt: pvt)
        #expect(throws: PDKProfileConsumptionError.cornerMismatch) {
            try matchPDKConsumption(claim(projection, corners: [corner]), against: projection, resources: resources)
        }
        let selection = projection.selections[0]
        let changed = try PDKProfileSelection(requirementID: selection.requirementID, cornerID: selection.cornerID,
            assetIDs: selection.assetIDs, sourceKeys: selection.sourceKeys, selectedSection: "foreign")
        #expect(throws: PDKProfileConsumptionError.selectionMismatch) {
            try matchPDKConsumption(claim(projection, selections: [changed]), against: projection, resources: resources)
        }
        #expect(throws: PDKProfileConsumptionError.selectionMismatch) {
            try matchPDKConsumption(claim(projection, selections: [selection, selection]), against: projection, resources: resources)
        }
    }
    @Test func requiredMappingsDoNotForceAnEnumeratedWholeLibraryToExecute() async throws {
        let fixture = try await ConsumptionFixture.make(.mapped); defer { fixture.cleanup() }
        let profile = try await fixture.admit()
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        let required = projection.knownMappings.filter { $0.name == "m" || $0.name == "M1" }
        #expect(required.count == 2)
        #expect(projection.mappingRequirements.count == 4)
        let partial = try #require(projection.knownMappings.first { $0.name == "partial" })
        #expect(partial.layerNumber == 9)
        #expect(partial.layerPurpose == nil)
        _ = try matchPDKConsumption(claim(projection, mappings: required), against: projection, resources: resources)
        _ = try matchPDKConsumption(claim(projection), against: projection, resources: resources)
        #expect(throws: PDKProfileConsumptionError.missingMapping(2)) {
            try matchPDKConsumption(claim(projection, mappings: required.filter { $0.name != "M1" }), against: projection, resources: resources)
        }
        #expect(throws: PDKProfileConsumptionError.missingMapping(1)) {
            try matchPDKConsumption(claim(projection, mappings: projection.knownMappings.filter { $0.name != "m" }), against: projection, resources: resources)
        }
    }
    @Test func alteredTerminalsLayersAndUnknownMappingsAreRejected() async throws {
        let fixture = try await ConsumptionFixture.make(.mapped); defer { fixture.cleanup() }
        let profile = try await fixture.admit()
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        let model = try #require(projection.knownMappings.first { $0.name == "m" })
        let layer = try #require(projection.knownMappings.first { $0.name == "M1" })
        for changed in [try PDKConsumedMapping(occurrenceID: model.occurrenceID, factKind: model.factKind, name: model.name,
                terminals: ["g", "d", "s", "b"], layerNumber: nil, layerPurpose: nil),
            try PDKConsumedMapping(occurrenceID: layer.occurrenceID, factKind: layer.factKind, name: layer.name,
                terminals: [], layerNumber: 2, layerPurpose: .drawing),
            try PDKConsumedMapping(occurrenceID: model.occurrenceID, factKind: model.factKind, name: "foreign",
                terminals: [], layerNumber: nil, layerPurpose: nil)] {
            #expect(throws: PDKProfileConsumptionError.unknownMapping(0)) {
                try matchPDKConsumption(claim(projection, mappings: [changed]), against: projection, resources: resources)
            }
        }
    }
    @Test func canonicalStageSetOrderIsStableAndConfigurationIsBound() async throws {
        let fixture = try await AdmissionFixture.make(alias: true); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let first = try projectPDKProfile(profile, for: stage(requirements: ["simulation", "alias"]), resources: resources)
        let second = try projectPDKProfile(profile, for: stage(requirements: ["alias", "simulation"]), resources: resources)
        let changed = try projectPDKProfile(profile, for: stage(requirements: ["alias", "simulation"], config: "other"), resources: resources)
        #expect(first.identity == second.identity)
        #expect(first.requirement.requirementIDs == ["alias", "simulation"])
        #expect(first.identity != changed.identity)
        _ = try matchPDKConsumption(claim(first, requirement: stage(requirements: ["simulation", "alias"])), against: second, resources: resources)
    }
    @Test func independentFramingVectorFixesTheStageIdentityVersion() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        var bytes: [UInt8] = []
        func uint(_ value: UInt64) { for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8(truncatingIfNeeded: value >> shift)) } }
        func text(_ value: String) { uint(UInt64(value.utf8.count)); bytes.append(contentsOf: value.utf8) }
        func reference(_ value: ArtifactReference) {
            text(value.digest.algorithm.rawValue); text(value.digest.hexadecimalValue); uint(value.byteCount)
            text(value.descriptor.role.rawValue); text(value.descriptor.kind.rawValue); text(value.descriptor.format.rawValue)
        }
        text("PDKKit.Profile.StageProjection"); uint(1)
        text("sha256"); text(profile.claim.semanticSelectionDigest.hexadecimalValue)
        text("native.stage"); text("config.v1"); uint(1); text("simulation"); uint(0)
        uint(0); uint(1); text("simulation"); bytes.append(0)
        uint(1); text("model"); uint(1); text("root"); bytes.append(0)
        uint(1); uint(0); text("root"); reference(fixture.rootReference)
        bytes.append(0); bytes.append(0); text("environment.empty.v1"); bytes.append(0); bytes.append(0)
        uint(2); uint(0); uint(0); text("devices"); uint(0); uint(1); text("m")
        let limits = try ContentDigestSessionLimits(maximumChunkByteCount: UInt64(bytes.count),
            maximumTotalByteCount: UInt64(bytes.count), maximumUpdateCount: 1)
        let expected = try SHA256ContentDigester().digest(using: .sha256, limits: limits) {
            (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in try lease.update(bytes)
        }.digest
        #expect(projection.identity == expected)
        #expect(resources.used(.hashedBytes) == UInt64(bytes.count))
    }

    private func admit(_ fixture: AdmissionFixture) async throws -> AdmittedPDKProfile {
        try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: fixture.definition.dependencies).registration()]).admit(fixture.request)
    }
    private func stage(requirements: [String] = ["simulation"], corners: [String] = [], config: String = "config.v1") throws -> PDKConsumerRequirement {
        try .init(stageID: "native.stage", requirementIDs: requirements, cornerIDs: corners, configurationIdentity: config)
    }
    private func claim(_ projection: PDKStageProjection, requirement: PDKConsumerRequirement? = nil,
                       profile: ContentDigest? = nil, identity: ContentDigest? = nil, sources: [PDKConsumedSource]? = nil,
                       mappings: [PDKConsumedMapping]? = nil, corners: [PDKProfileCorner]? = nil,
                       selections: [PDKProfileSelection]? = nil) throws -> PDKConsumptionClaim {
        try .init(stageRequirement: requirement ?? projection.requirement, profileIdentity: profile ?? projection.profile.claim.semanticSelectionDigest,
            expectedProjectionIdentity: identity ?? projection.identity, actualSources: sources ?? Array(projection.sources),
            actualMappings: mappings ?? Array(projection.knownMappings), actualCorners: corners ?? Array(projection.corners),
            actualSelections: selections ?? Array(projection.selections), domainEvidenceReference: projection.sources[0].reference)
    }
    private func source(_ original: PDKConsumedSource, id: UInt64? = nil, reference: ArtifactReference? = nil,
                        section: String? = nil, preprocessing: String? = nil) throws -> PDKConsumedSource {
        try .init(occurrenceID: id ?? original.occurrenceID, sourceKey: original.sourceKey, reference: reference ?? original.reference,
            cornerID: original.cornerID, selectedSection: section ?? original.selectedSection,
            preprocessingIdentity: preprocessing ?? original.preprocessingIdentity, parentOccurrenceID: original.parentOccurrenceID,
            incomingDependency: original.incomingDependency)
    }
}
