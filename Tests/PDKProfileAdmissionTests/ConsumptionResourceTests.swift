import PDKCore
@testable import PDKProfileAdmission
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ConsumptionResourceTests {
    private final class Clock: PDKAdmissionExecutionClock {
        private let instant = Mutex(ContinuousClock.now)
        func now() -> ContinuousClock.Instant { instant.withLock { $0 } }
        func advance(_ duration: Duration) { instant.withLock { $0 = $0.advanced(by: duration) } }
    }

    private func budget(_ limit: (PDKAdmissionResourceDimension, UInt64)? = nil,
                        elapsed: UInt64 = 10_000_000_000) throws -> PDKAdmissionBudget {
        var limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64(100_000_000)) })
        if let limit { limits[limit.0] = limit.1 }
        return try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: elapsed)
    }

    private func stage() throws -> PDKConsumerRequirement {
        try .init(stageID: "simulation", requirementIDs: ["simulation"], cornerIDs: [], configurationIdentity: "configuration.v1")
    }

    private func admit(_ fixture: AdmissionFixture, probe: AdmissionCaptureProbe? = nil) async throws -> AdmittedPDKProfile {
        let provider = try AdmissionScriptInspector(edges: fixture.definition.dependencies).registration()
        if let probe { return try await LocalPDKProfileAdmitter(inspectors: [provider], capture: probe).admit(fixture.request) }
        return try await LocalPDKProfileAdmitter(inspectors: [provider]).admit(fixture.request)
    }

    private func claim(_ projection: PDKStageProjection) throws -> PDKConsumptionClaim {
        try .init(stageRequirement: projection.requirement, profileIdentity: projection.profile.claim.semanticSelectionDigest,
                  expectedProjectionIdentity: projection.identity, actualSources: Array(projection.sources),
                  actualMappings: Array(projection.knownMappings), actualCorners: Array(projection.corners),
                  actualSelections: Array(projection.selections), domainEvidenceReference: projection.profile.manifest.reference)
    }

    @Test(arguments: [PDKAdmissionResourceDimension.parserWork, .hashedBytes, .temporaryBytes, .liveOwnedBytes])
    func quotaRefusalReleasesAllNewProjectionCapacity(dimension: PDKAdmissionResourceDimension) async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: try budget((dimension, 1)))
        let requirement = try stage()
        do throws(PDKProfileConsumptionError) {
            _ = try projectPDKProfile(profile, for: requirement, resources: resources)
            Issue.record("A stage exceeded its invocation quota")
        } catch {
            guard case .resource(.exhausted(let failed, _, _)) = error else { Issue.record("Unexpected quota refusal: \(error)"); return }
            #expect(failed == dimension)
        }
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
        resources.close()
    }

    @Test func cancelledStructuredCallerCannotProjectOrMatch() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let stageResources = LocalPDKAdmissionResources(budget: try budget()); defer { stageResources.close() }
        let requirement = try stage()
        let projection = try projectPDKProfile(profile, for: requirement, resources: stageResources)
        let actual = try claim(projection)
        let cancelled = LocalPDKAdmissionResources(budget: try budget()); defer { cancelled.close() }
        let refused = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                withUnsafeCurrentTask { $0?.cancel() }
                do throws(PDKProfileConsumptionError) { _ = try projectPDKProfile(profile, for: requirement, resources: cancelled); return false }
                catch { guard error == .resource(.cancelled) else { return false } }
                do throws(PDKProfileConsumptionError) { _ = try matchPDKConsumption(actual, against: projection, resources: cancelled); return false }
                catch { return error == .resource(.cancelled) }
            }
            return await group.next() ?? false
        }
        #expect(refused)
        #expect(cancelled.used(.liveOwnedBytes) == 0)
    }

    @Test func matchingUsesTheOriginalStageDeadline() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let clock = Clock()
        let resources = LocalPDKAdmissionResources(budget: try budget(elapsed: 100), clock: clock)
        defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        let actual = try claim(projection)
        let held = resources.used(.liveOwnedBytes)
        clock.advance(.nanoseconds(100))
        #expect(throws: PDKProfileConsumptionError.resource(.deadlineExceeded)) {
            try matchPDKConsumption(actual, against: projection, resources: resources)
        }
        #expect(resources.used(.liveOwnedBytes) == held)
        #expect(resources.used(.temporaryBytes) == 0)
    }

    @Test func finalProjectionCheckRefusesPublicationAndReleasesBuiltOutput() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let requirement = try stage()
        let baseline = ConsumptionResources(budget: try budget()); defer { baseline.native.close() }
        var published: PDKStageProjection? = try projectPDKProfile(profile, for: requirement, resources: baseline)
        #expect(published != nil)
        let lastCheck = baseline.checks
        published = nil
        #expect(baseline.native.used(.liveOwnedBytes) == 0)
        let failed = ConsumptionResources(budget: try budget()); defer { failed.native.close() }
        failed.fail(at: lastCheck, with: .cancelled)
        #expect(throws: PDKProfileConsumptionError.resource(.cancelled)) {
            try projectPDKProfile(profile, for: requirement, resources: failed)
        }
        #expect(failed.checks == lastCheck)
        #expect(failed.native.used(.hashedBytes) > 0)
        #expect(failed.native.used(.liveOwnedBytes) == 0)
        #expect(failed.native.used(.temporaryBytes) == 0)
    }

    @Test func finalMatchCheckRefusesPublicationAndReleasesEvidenceStorage() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let profile = try await admit(fixture)
        let resources = LocalPDKAdmissionResources(budget: try budget()); defer { resources.close() }
        let projection = try projectPDKProfile(profile, for: stage(), resources: resources)
        let actual = try claim(projection)
        let baseline = ConsumptionResources(budget: try budget()); defer { baseline.native.close() }
        var published: PDKMatchedConsumption? = try matchPDKConsumption(actual, against: projection, resources: baseline)
        #expect(published != nil)
        let lastCheck = baseline.checks
        published = nil
        #expect(baseline.native.used(.liveOwnedBytes) == 0)
        let failed = ConsumptionResources(budget: try budget()); defer { failed.native.close() }
        failed.fail(at: lastCheck)
        #expect(throws: PDKProfileConsumptionError.resource(.deadlineExceeded)) {
            try matchPDKConsumption(actual, against: projection, resources: failed)
        }
        #expect(failed.checks == lastCheck)
        #expect(failed.native.used(.liveOwnedBytes) == 0)
        #expect(failed.native.used(.temporaryBytes) == 0)
    }

    @Test func copiedMatchedOwnerKeepsParentSupportAndAllChargesUntilLastRelease() async throws {
        let fixture = try await AdmissionFixture.make(support: true); defer { fixture.cleanup() }
        let probe = AdmissionCaptureProbe()
        var profile: AdmittedPDKProfile? = try await admit(fixture, probe: probe)
        let original = try #require(probe.resources)
        let admittedCapacity = original.used(.liveOwnedBytes)
        #expect(throws: PDKAdmissionResourceError.closed) { try original.check() }
        let stageResources = LocalPDKAdmissionResources(budget: try budget())
        let matchResources = LocalPDKAdmissionResources(budget: try budget())
        var projection: PDKStageProjection? = try projectPDKProfile(profile!, for: stage(), resources: stageResources)
        #expect(projection!.sources.count == 1)
        #expect(original.used(.liveOwnedBytes) == admittedCapacity)
        #expect(stageResources.used(.readBytes) == 0)
        #expect(stageResources.used(.uniqueSources) == 0)
        #expect(projection!.profile.claim.mandatorySupportSourceKeys == ["support"])
        var actual: PDKConsumptionClaim? = try claim(projection!)
        var matched: PDKMatchedConsumption? = try matchPDKConsumption(actual!, against: projection!, resources: matchResources)
        var copy = matched
        #expect(copy != nil)
        actual = nil; projection = nil; profile = nil
        stageResources.close(); matchResources.close()
        #expect(original.used(.liveOwnedBytes) > 0)
        #expect(stageResources.used(.liveOwnedBytes) > 0)
        #expect(matchResources.used(.liveOwnedBytes) > 0)
        matched = nil
        #expect(original.used(.liveOwnedBytes) > 0)
        #expect(stageResources.used(.liveOwnedBytes) > 0)
        #expect(matchResources.used(.liveOwnedBytes) > 0)
        copy = nil
        #expect(original.used(.liveOwnedBytes) == 0)
        #expect(stageResources.used(.liveOwnedBytes) == 0)
        #expect(matchResources.used(.liveOwnedBytes) == 0)
        #expect(stageResources.used(.temporaryBytes) == 0)
    }
}
