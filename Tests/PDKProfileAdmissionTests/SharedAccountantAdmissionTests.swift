import PDKCore
@testable import PDKProfileAdmission
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SharedAccountantAdmissionTests {
    @Test func protocolAccountantCarriesInputAdmissionAndOutputWithoutClosing() async throws {
        let fixture = try await AdmissionFixture.make(support: true)
        defer { fixture.cleanup() }
        let resources = ForwardingAdmissionAccountant(budget: fixture.request.budget)
        defer { resources.owner.close() }
        _ = try resources.reserve(.init(dimension: .readBytes, amount: 7))
        let admitting: any PDKProfileAdmitting = LocalPDKProfileAdmitter(
            inspectors: [try AdmissionScriptInspector(edges: []).registration()])
        var profile: AdmittedPDKProfile? = try await admitting.admit(fixture.request, resources: resources)
        #expect(profile?.authority.resources as? ForwardingAdmissionAccountant === resources)
        #expect(resources.owner.used(.readBytes) == fixture.expectedReadBytes + 7)
        try resources.check()
        let publicationWork = resources.owner.used(.parserWork)
        _ = try resources.reserve(.init(dimension: .parserWork, amount: 11))
        #expect(resources.owner.used(.parserWork) == publicationWork + 11)
        var copy = profile
        let retained = resources.owner.used(.liveOwnedBytes)
        profile = nil
        #expect(copy?.sourceFacts.count == 2)
        #expect(resources.owner.used(.liveOwnedBytes) == retained)
        copy = nil
        #expect(resources.owner.used(.liveOwnedBytes) == 0)
        try resources.check()
    }

    @Test func precedingWorkCannotBeResetByAdmission() async throws {
        let fixture = try await AdmissionFixture.make()
        defer { fixture.cleanup() }
        let resources = ForwardingAdmissionAccountant(budget: fixture.request.budget)
        defer { resources.owner.close() }
        let limit = try #require(fixture.request.budget.limits[.parserWork])
        _ = try resources.reserve(.init(dimension: .parserWork, amount: limit))
        let admitting = LocalPDKProfileAdmitter(inspectors: [try AdmissionScriptInspector(edges: []).registration()])
        do {
            _ = try await admitting.admit(fixture.request, resources: resources)
            Issue.record("Admission reset the preceding invocation work")
        } catch {
            #expect(error == .resource(.exhausted(dimension: .parserWork, limit: limit, attempted: limit + 1)))
        }
        #expect(resources.owner.used(.parserWork) == limit)
        #expect(resources.owner.used(.readBytes) == 0)
        #expect(resources.owner.used(.liveOwnedBytes) == 0)
        try resources.check()
    }

    @Test func failureLeavesExternalOwnerOpenAndReleasesItsWork() async throws {
        let fixture = try await AdmissionFixture.make()
        defer { fixture.cleanup() }
        let resources = ForwardingAdmissionAccountant(budget: fixture.request.budget)
        defer { resources.owner.close() }
        let inspector = AdmissionScriptInspector(edges: [], behavior: .unsupported)
        let admitting: any PDKProfileAdmitting = LocalPDKProfileAdmitter(inspectors: [try inspector.registration()])
        do {
            _ = try await admitting.admit(fixture.request, resources: resources)
            Issue.record("Unsupported facts published a profile")
        } catch { #expect(error == .unsupportedSemantics) }
        #expect(resources.owner.used(.readBytes) == fixture.expectedReadBytes)
        #expect(resources.owner.used(.liveOwnedBytes) == 0)
        #expect(resources.owner.used(.temporaryBytes) == 0)
        #expect(resources.owner.used(.openResources) == 0)
        try resources.check()
    }

    @Test func externalDeadlineStartsBeforeAdmission() async throws {
        let fixture = try await AdmissionFixture.make()
        defer { fixture.cleanup() }
        let clock = SharedAdmissionClock()
        let owner = LocalPDKAdmissionResources(budget: fixture.request.budget, clock: clock)
        defer { owner.close() }
        clock.expire()
        let admitting = LocalPDKProfileAdmitter(inspectors: [try AdmissionScriptInspector(edges: []).registration()])
        do {
            _ = try await admitting.admit(fixture.request, resources: owner)
            Issue.record("Admission replaced the original invocation deadline")
        } catch { #expect(error == .resource(.deadlineExceeded)) }
        #expect(owner.used(.readBytes) == 0)
        #expect(throws: PDKAdmissionResourceError.deadlineExceeded) { try owner.check() }
    }
}

private final class ForwardingAdmissionAccountant: PDKAdmissionResourceAccounting {
    let owner: LocalPDKAdmissionResources
    init(budget: PDKAdmissionBudget) { owner = .init(budget: budget) }
    func check() throws(PDKAdmissionResourceError) { try owner.check() }
    func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
        try owner.reserve(cost)
    }
}

private final class SharedAdmissionClock: PDKAdmissionExecutionClock {
    private let instant = Mutex(ContinuousClock.now)
    func now() -> ContinuousClock.Instant { instant.withLock { $0 } }
    func expire() { instant.withLock { $0 += .seconds(20) } }
}
