import Foundation
import Synchronization
import Testing
import CircuiteFoundation
@testable import PDKCore

@Suite struct ProfileAccountingTests {
    @Test func constructorsCheckTerminalStateAndByteWork() throws {
        let accounting = ProfileTestAccounting()
        accounting.failure = .cancelled
        #expect(throws: PDKProfileValueError.resource(.cancelled)) {
            try PDKConsumerRequirement(stageID: "stage", requirementIDs: ["r"], cornerIDs: [], configurationIdentity: "config", resources: accounting)
        }
        accounting.failure = .deadlineExceeded
        #expect(throws: PDKProfileValueError.resource(.deadlineExceeded)) {
            try PDKProfileWire.unique(["a", "b"], resources: accounting)
        }
        accounting.failure = nil
        accounting.limit(.parserWork, to: 20)
        let long = String(repeating: "a", count: 1000)
        #expect(throws: PDKProfileValueError.self) { try PDKProfileWire.unique([long, long], resources: accounting) }
        #expect(accounting.used(.parserWork) <= 20)
        #expect(accounting.used(.temporaryBytes) == 0)
    }

    @Test func checkedCapacityOverflowRefusesBeforeReservation() throws {
        let accounting = ProfileTestAccounting()
        let work = PDKProfileConstructionWork(accounting)
        #expect(throws: PDKProfileValueError.resource(.arithmeticOverflow(.temporaryBytes))) {
            try work.temporary(String.self, capacity: Int.max)
        }
        #expect(accounting.reservationCount == 0)
    }

    @Test func canonicalCapacityHashWorkAndGoldenIdentity() throws {
        let fixture = try ProfileValueTests().fixture(temperature: 0)
        let baseline = try ProfileValueTests().claim(fixture)
        let accounting = ProfileTestAccounting()
        let plan = try PDKProfilePlan(definition: fixture.0, manifest: fixture.1, manifestReference: fixture.0.manifestReference, resources: accounting)
        let claim = try PDKProfileClaim(definitionReference: fixture.2, plan: plan, resources: accounting)
        #expect(claim.semanticSelectionDigest == baseline.semanticSelectionDigest)
        #expect(try claim.canonicalBytes() == CanonicalGoldenVector.bytes)
        #expect(accounting.used(.hashedBytes) == UInt64(CanonicalGoldenVector.bytes.count))
        #expect(accounting.used(.temporaryBytes) == 0)
        #expect(accounting.peak(.temporaryBytes) >= UInt64(CanonicalGoldenVector.bytes.count))
        let refused = ProfileTestAccounting()
        refused.limit(.hashedBytes, to: 1)
        #expect(throws: PDKProfileValueError.self) {
            try PDKProfileCanonicalEncoding().digest([1, 2], resources: refused)
        }
        #expect(refused.used(.hashedBytes) == 0)
        #expect(refused.used(.temporaryBytes) == 0)
    }

    @Test func planAndClaimRetainSharedStorageUntilLastCopy() throws {
        let fixture = try ProfileValueTests().fixture(dependencies: true)
        let accounting = ProfileTestAccounting()
        var last: PDKProfileClaim?
        do {
            let plan = try PDKProfilePlan(definition: fixture.0, manifest: fixture.1, manifestReference: fixture.0.manifestReference, resources: accounting)
            let heldByPlan = accounting.used(.liveOwnedBytes)
            let claim = try PDKProfileClaim(definitionReference: fixture.2, plan: plan, resources: accounting)
            last = claim
            #expect(accounting.used(.liveOwnedBytes) > heldByPlan)
            #expect(accounting.used(.temporaryBytes) == 0)
        }
        #expect(last?.dependencies.count == 1)
        #expect(accounting.used(.liveOwnedBytes) > 0)
        last = nil
        #expect(accounting.used(.liveOwnedBytes) == 0)
    }

    @Test func decodingContextNeverFallsBackAndForwardsCancellation() throws {
        let original = try PDKConsumerRequirement(stageID: "s", requirementIDs: ["r"], cornerIDs: [], configurationIdentity: "c")
        let bytes = try JSONEncoder().encode(original)
        let decoder = JSONDecoder()
        decoder.userInfo[PDKAdmissionDecodingContext.accountingKey] = "invalid"
        #expect(throws: PDKProfileValueError.self) { try decoder.decode(PDKConsumerRequirement.self, from: bytes) }
        let accounting = ProfileTestAccounting()
        accounting.failure = .cancelled
        decoder.userInfo[PDKAdmissionDecodingContext.accountingKey] = accounting
        #expect(throws: PDKProfileValueError.resource(.cancelled)) { try decoder.decode(PDKConsumerRequirement.self, from: bytes) }
        accounting.failure = nil
        #expect(try decoder.decode(PDKConsumerRequirement.self, from: bytes) == original)
        #expect(accounting.used(.parserWork) > 0)
        #expect(accounting.used(.temporaryBytes) == 0)
    }

    @Test func boundedUnicodeNormalizationRefusesAndStandalonePreservesPolicy() throws {
        let accounting = ProfileTestAccounting()
        let kind = try ArtifactKind(rawValue: "ΜODEL")
        #expect(throws: PDKProfileValueError.resource(.unsupportedBudgetCapability("Cooperative Unicode kind normalization"))) {
            try PDKProfileConstructionWork(accounting).technologyKind(kind)
        }
        #expect(try PDKProfileConstructionWork(nil).technologyKind(kind) == false)
        #expect(try PDKProfileConstructionWork(accounting).technologyKind(ArtifactKind(rawValue: "PDK.Technology")))
        // Canonically equivalent strings preserve Swift value semantics under checked work.
        #expect(try PDKProfileConstructionWork(accounting).equal("é", "e\u{301}"))
    }
}
