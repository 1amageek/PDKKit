import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import PDKCore
@testable import PDKProfileAdmission
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ExecutionBindingTests {
    @Test func directAndExternalEntriesRetainTheCompleteGraph() async throws {
        for external in [false, true] {
            let fixture = try await ExecutionBindingFixture.make(graph: .repeated, external: external); defer { fixture.cleanup() }
            let matched = try fixture.match()
            #expect(matched.sources.count == (external ? 4 : 3))
            #expect(matched.sources[external ? 1 : 0].parentOccurrenceID == (external ? 40 : nil))
            #expect(matched.sourceBindings.count == 3)
            #expect(matched.entries[0] == fixture.claim.entries[0])
            #expect(matched.consumption.projection.identity == fixture.projection.identity)
        }
    }
    @Test func externalParentWithoutCornerCanEnterACornerScopedRoot() async throws {
        let fixture = try await ExecutionBindingFixture.make(corner: true); defer { fixture.cleanup() }
        let matched = try fixture.match()
        #expect(matched.sources[0].cornerID == nil)
        #expect(matched.sources[1].cornerID == "tt")
        #expect(matched.entries[0].externalParentOccurrenceID == 40)
    }
    @Test func oneExternalParentCanEnterDistinctCornerScopedSubtrees() async throws {
        let fixture = try await ConsumptionFixture.make(.multiCorner); defer { fixture.cleanup() }
        let profile = try await fixture.admit()
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let requirement = try PDKConsumerRequirement(stageID: "native.stage", requirementIDs: ["simulation"], cornerIDs: ["tt", "ss"], configurationIdentity: "config.v1")
        let projection = try projectPDKProfile(profile, for: requirement, resources: resources)
        let parentReference = try #require(fixture.base.definition.sources.last).reference
        let parent = try PDKConsumedSource(occurrenceID: 40, sourceKey: "circuit", reference: parentReference, cornerID: nil,
            selectedSection: nil, preprocessingIdentity: "environment.empty.v1", parentOccurrenceID: nil, incomingDependency: nil)
        var sources = [parent], bindings: [PDKExecutionSourceBinding] = [], entries: [PDKExecutionEntry] = []
        for (index, projected) in projection.sources.enumerated() {
            let executionID = UInt64(index) + 41
            let incoming: PDKSourceDependency
            let parentID: UInt64
            if let profileParent = projected.parentOccurrenceID {
                incoming = try #require(projected.incomingDependency); parentID = profileParent + 41
            } else {
                parentID = 40
                incoming = try .init(parentSourceKey: parent.sourceKey, parentReference: parent.reference,
                    statementByteOffset: UInt64(index), statementOrdinal: UInt64(index), directiveKind: "include", literalRoute: "root.sp",
                    childSourceKey: projected.sourceKey, childReference: projected.reference,
                    selectedSection: projected.selectedSection, preprocessingIdentity: projected.preprocessingIdentity, lexicalOrder: UInt64(index))
                entries.append(try .init(profileRootOccurrenceID: projected.occurrenceID, executionRootOccurrenceID: executionID,
                    externalParentOccurrenceID: 40, externalParentReference: parent.reference, incomingDependency: incoming))
            }
            sources.append(try .init(occurrenceID: executionID, sourceKey: projected.sourceKey, reference: projected.reference,
                cornerID: projected.cornerID, selectedSection: projected.selectedSection, preprocessingIdentity: projected.preprocessingIdentity,
                parentOccurrenceID: parentID, incomingDependency: incoming))
            bindings.append(try .init(profileOccurrenceID: projected.occurrenceID, executionOccurrenceID: executionID))
        }
        let identity = try PDKProfileCanonicalEncoding().digest(Array(JSONEncoder().encode(sources)))
        let observation = try PDKExecutionSourceObservation(executionInputIdentity: identity, configurationIdentity: requirement.configurationIdentity,
            grammarPolicyIdentity: "controlled.graph.v1", sources: sources)
        let scoped = try PDKConsumptionClaim(stageRequirement: requirement, profileIdentity: profile.claim.semanticSelectionDigest,
            expectedProjectionIdentity: projection.identity, actualSources: Array(projection.sources), actualMappings: Array(projection.knownMappings),
            actualCorners: Array(projection.corners), actualSelections: Array(projection.selections), domainEvidenceReference: parent.reference)
        let claim = try PDKExecutionConsumptionClaim(scopedClaim: scoped, executionInputIdentity: identity, sourceBindings: bindings, entries: entries)
        let matched = try matchPDKExecutionConsumption(claim, against: projection, observed: observation, resources: resources)
        #expect(matched.entries.count == 2)
        #expect(matched.sources[1].cornerID == "ss")
        #expect(matched.sources[3].cornerID == "tt")
        #expect(matched.sources[1].parentOccurrenceID == 40)
        #expect(matched.sources[3].parentOccurrenceID == 40)
    }
    @Test func physicalEntryAndExternalParentTamperingRefuse() async throws {
        let fixture = try await ExecutionBindingFixture.make(); defer { fixture.cleanup() }
        let old = try #require(fixture.claim.entries[0].incomingDependency)
        let edge = try dependency(old, offset: old.statementByteOffset + 1)
        let changed = try PDKExecutionEntry(profileRootOccurrenceID: 0, executionRootOccurrenceID: 41,
            externalParentOccurrenceID: 40, externalParentReference: old.parentReference, incomingDependency: edge)
        #expect(throws: PDKProfileConsumptionError.executionEntryMismatch(0)) { try fixture.match(fixture.claim(entries: [changed])) }
        let missing = try PDKExecutionEntry(profileRootOccurrenceID: 0, executionRootOccurrenceID: 41,
            externalParentOccurrenceID: nil, externalParentReference: nil, incomingDependency: nil)
        #expect(throws: PDKProfileConsumptionError.executionEntryMismatch(0)) { try fixture.match(fixture.claim(entries: [missing])) }
        let wrongParent = try PDKExecutionEntry(profileRootOccurrenceID: 0, executionRootOccurrenceID: 41,
            externalParentOccurrenceID: 999, externalParentReference: old.parentReference, incomingDependency: old)
        #expect(throws: PDKProfileConsumptionError.executionEntryMismatch(0)) { try fixture.match(fixture.claim(entries: [wrongParent])) }
    }
    @Test func inheritedContextSectionAndFullDescriptorAreStrict() async throws {
        let fixture = try await ExecutionBindingFixture.make(); defer { fixture.cleanup() }
        let source = fixture.observed.sources[1]
        let changedReference = ArtifactReference(id: source.reference.id,
            descriptor: .init(role: .output, kind: source.reference.descriptor.kind, format: source.reference.descriptor.format))
        for changed in [try replacing(source, preprocessing: "environment.inherited.param.v2"),
                        try replacing(source, section: "SS"), try replacing(source, reference: changedReference)] {
            #expect(throws: PDKProfileConsumptionError.executionContextMismatch(0)) {
                try fixture.match(nil, fixture.observation(sources: [fixture.observed.sources[0], changed]))
            }
        }
    }
    @Test func missingExtraRepeatedAndReorderedContributorsRefuse() async throws {
        let fixture = try await ExecutionBindingFixture.make(graph: .repeated); defer { fixture.cleanup() }
        #expect(throws: PDKProfileConsumptionError.unknownExecutionOccurrence(43)) {
            try fixture.match(nil, fixture.observation(sources: Array(fixture.observed.sources.prefix(3))))
        }
        let extra = try replacing(fixture.observed.sources[2], id: 44)
        #expect(throws: PDKProfileConsumptionError.unrepresentedExecutionContributor(4)) {
            try fixture.match(nil, fixture.observation(sources: fixture.observed.sources + [extra]))
        }
        let outsideEdge = try PDKSourceDependency(parentSourceKey: fixture.observed.sources[0].sourceKey,
            parentReference: fixture.observed.sources[0].reference, statementByteOffset: 18, statementOrdinal: 2,
            directiveKind: "include", literalRoute: "child.sp", childSourceKey: extra.sourceKey, childReference: extra.reference,
            selectedSection: extra.selectedSection, preprocessingIdentity: extra.preprocessingIdentity, lexicalOrder: 3)
        let outsideChild = try PDKConsumedSource(occurrenceID: 44, sourceKey: extra.sourceKey, reference: extra.reference,
            cornerID: extra.cornerID, selectedSection: extra.selectedSection, preprocessingIdentity: extra.preprocessingIdentity,
            parentOccurrenceID: 40, incomingDependency: outsideEdge)
        #expect(throws: PDKProfileConsumptionError.unrepresentedExecutionContributor(4)) {
            try fixture.match(nil, fixture.observation(sources: fixture.observed.sources + [outsideChild]))
        }
        let duplicateRoot = try replacing(fixture.observed.sources[1], id: 44)
        #expect(throws: PDKProfileConsumptionError.unrepresentedExecutionContributor(4)) {
            try fixture.match(nil, fixture.observation(sources: fixture.observed.sources + [duplicateRoot]))
        }
        #expect(throws: PDKProfileConsumptionError.executionBindingMismatch(2)) {
            try fixture.match(nil, fixture.observation(sources: [fixture.observed.sources[0], fixture.observed.sources[1], fixture.observed.sources[3], fixture.observed.sources[2]]))
        }
    }
    @Test func descendantPhysicalEdgeAndParentCannotBeSubstituted() async throws {
        let fixture = try await ExecutionBindingFixture.make(graph: .nested); defer { fixture.cleanup() }
        let child = fixture.observed.sources[2], old = try #require(fixture.observed.sources[2].incomingDependency)
        let changed = try replacing(child, edge: dependency(old, offset: 123))
        #expect(throws: PDKProfileConsumptionError.executionBindingMismatch(1)) {
            try fixture.match(nil, fixture.observation(sources: [fixture.observed.sources[0], fixture.observed.sources[1], changed]))
        }
    }
    @Test func fullInputAndConfigurationIdentityCannotDrift() async throws {
        let fixture = try await ExecutionBindingFixture.make(); defer { fixture.cleanup() }
        let changed = try ContentDigest(algorithm: .sha256, hexadecimalValue: String(repeating: "f", count: 64))
        #expect(throws: PDKProfileConsumptionError.executionInputMismatch) { try fixture.match(nil, fixture.observation(input: changed)) }
        #expect(throws: PDKProfileConsumptionError.executionConfigurationMismatch) { try fixture.match(nil, fixture.observation(configuration: "actual.config.v2")) }
        #expect(try fixture.match().bindingIdentity != fixture.match(fixture.claim(input: changed), fixture.observation(input: changed)).bindingIdentity)
    }
    @Test func strictWireRoundTripAndStructuralFailures() async throws {
        let fixture = try await ExecutionBindingFixture.make(); defer { fixture.cleanup() }
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        #expect(try decoder.decode(PDKExecutionConsumptionClaim.self, from: encoder.encode(fixture.claim)) == fixture.claim)
        #expect(try decoder.decode(PDKExecutionSourceObservation.self, from: encoder.encode(fixture.observed)) == fixture.observed)
        var object = try #require(JSONSerialization.jsonObject(with: encoder.encode(fixture.claim)) as? [String: Any])
        object["schemaVersion"] = 2
        #expect(throws: (any Error).self) { try decoder.decode(PDKExecutionConsumptionClaim.self, from: JSONSerialization.data(withJSONObject: object)) }
        var entry = try #require(JSONSerialization.jsonObject(with: encoder.encode(fixture.claim.entries[0])) as? [String: Any])
        entry.removeValue(forKey: "externalParentReference")
        #expect(throws: (any Error).self) { try decoder.decode(PDKExecutionEntry.self, from: JSONSerialization.data(withJSONObject: entry)) }
        #expect(throws: PDKProfileValueError.duplicateKey("Execution occurrence")) { try fixture.observation(sources: fixture.observed.sources + [fixture.observed.sources[1]]) }
        let nested = try await ExecutionBindingFixture.make(graph: .nested); defer { nested.cleanup() }
        let duplicated = try PDKExecutionSourceBinding(profileOccurrenceID: 1, executionOccurrenceID: nested.claim.sourceBindings[0].executionOccurrenceID)
        #expect(throws: PDKProfileValueError.duplicateKey("Execution binding occurrence")) {
            try PDKExecutionConsumptionClaim(scopedClaim: nested.claim.scopedClaim, executionInputIdentity: nested.claim.executionInputIdentity,
                sourceBindings: [nested.claim.sourceBindings[0], duplicated], entries: nested.claim.entries)
        }
    }
    @Test func retainedCapacityReleasesOnlyAfterTheLastOutputCopy() async throws {
        let fixture = try await ExecutionBindingFixture.make(); defer { fixture.cleanup() }
        let resources = LocalPDKAdmissionResources(budget: fixture.fixture.request.budget)
        var first: PDKMatchedExecutionConsumption? = try fixture.match(resources: resources)
        var last = first
        let used = resources.used(.liveOwnedBytes)
        #expect(used > 0); #expect(resources.used(.temporaryBytes) == 0)
        resources.close(); first = nil
        #expect(resources.used(.liveOwnedBytes) == used)
        #expect(last?.sources.count == 2)
        last = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
    }
    @Test func workCapacityCancellationAndFinalPublicationFailureReleaseStorage() async throws {
        let fixture = try await ExecutionBindingFixture.make(); defer { fixture.cleanup() }
        for dimension in [PDKAdmissionResourceDimension.parserWork, .liveOwnedBytes, .temporaryBytes, .hashedBytes] {
            var limits = fixture.fixture.request.budget.limits; limits[dimension] = 1
            let resources = LocalPDKAdmissionResources(budget: try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: 10_000_000_000))
            do {
                _ = try fixture.match(resources: resources)
                Issue.record("Expected checked resource exhaustion")
            } catch let error as PDKProfileConsumptionError {
                guard case .resource(.exhausted(let actual, _, _)) = error else { throw error }
                #expect(actual == dimension)
            }
            #expect(resources.used(.liveOwnedBytes) == 0); #expect(resources.used(.temporaryBytes) == 0)
            resources.close()
        }
        let baseline = ConsumptionResources(budget: fixture.fixture.request.budget)
        _ = try fixture.match(resources: baseline)
        let count = baseline.checks
        for check in [1, count / 2, count] {
            let resources = ConsumptionResources(budget: fixture.fixture.request.budget)
            resources.fail(at: check, with: .cancelled)
            #expect(throws: PDKProfileConsumptionError.resource(.cancelled)) { try fixture.match(resources: resources) }
            #expect(resources.native.used(.liveOwnedBytes) == 0); #expect(resources.native.used(.temporaryBytes) == 0)
        }
    }
    @Test func independentBindingFramingVectorKeepsTheProjectionUnchanged() async throws {
        let fixture = try await ExecutionBindingFixture.make(external: false); defer { fixture.cleanup() }
        let matched = try fixture.match()
        var bytes: [UInt8] = []
        func uint(_ value: UInt64) { for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8(truncatingIfNeeded: value >> shift)) } }
        func string(_ value: String) { uint(UInt64(value.utf8.count)); bytes.append(contentsOf: value.utf8) }
        string("PDKKit.Profile.ExecutionBinding"); uint(1)
        string("sha256"); string(fixture.projection.identity.hexadecimalValue)
        string("sha256"); string(fixture.observed.executionInputIdentity.hexadecimalValue)
        uint(1); uint(0); uint(40); uint(1); uint(0); uint(40); bytes.append(0)
        let limits = try ContentDigestSessionLimits(maximumChunkByteCount: UInt64(bytes.count), maximumTotalByteCount: UInt64(bytes.count), maximumUpdateCount: 1)
        let expected = try SHA256ContentDigester().digest(using: .sha256, limits: limits) { (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in try lease.update(bytes) }.digest
        #expect(matched.bindingIdentity == expected)
        #expect(matched.consumption.projection.identity == fixture.projection.identity)
    }
    private func dependency(_ edge: PDKSourceDependency, offset: UInt64? = nil, preprocessing: String? = nil,
                            section: String? = nil, childReference: ArtifactReference? = nil) throws -> PDKSourceDependency {
        try .init(parentSourceKey: edge.parentSourceKey, parentReference: edge.parentReference,
            statementByteOffset: offset ?? edge.statementByteOffset, statementOrdinal: edge.statementOrdinal,
            directiveKind: edge.directiveKind, literalRoute: edge.literalRoute, childSourceKey: edge.childSourceKey,
            childReference: childReference ?? edge.childReference, selectedSection: section ?? edge.selectedSection,
            preprocessingIdentity: preprocessing ?? edge.preprocessingIdentity, lexicalOrder: edge.lexicalOrder)
    }
    private func replacing(_ source: PDKConsumedSource, id: UInt64? = nil, preprocessing: String? = nil,
                           section: String? = nil, reference: ArtifactReference? = nil, edge: PDKSourceDependency? = nil) throws -> PDKConsumedSource {
        let incoming: PDKSourceDependency?
        if let edge { incoming = edge } else if let old = source.incomingDependency {
            incoming = try dependency(old, preprocessing: preprocessing, section: section, childReference: reference)
        } else { incoming = nil }
        return try .init(occurrenceID: id ?? source.occurrenceID, sourceKey: source.sourceKey,
            reference: reference ?? source.reference, cornerID: source.cornerID, selectedSection: section ?? source.selectedSection,
            preprocessingIdentity: preprocessing ?? source.preprocessingIdentity, parentOccurrenceID: source.parentOccurrenceID, incomingDependency: incoming)
    }
}
