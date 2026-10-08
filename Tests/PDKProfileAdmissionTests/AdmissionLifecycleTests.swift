import CircuiteFoundation
import Foundation
import PDKCore
@testable import PDKProfileAdmission
import PDKSourceCapture
import Synchronization
import Testing

private actor AdmissionCaptureGate {
    private var entered = false
    private var released = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func block() async {
        entered = true; enteredWaiter?.resume(); enteredWaiter = nil
        if !released { await withCheckedContinuation { releaseWaiter = $0 } }
    }
    func waitUntilEntered() async {
        if !entered { await withCheckedContinuation { enteredWaiter = $0 } }
    }
    func release() { released = true; releaseWaiter?.resume(); releaseWaiter = nil }
}
private struct GatedAdmissionCapture: PDKBoundedLocalSourceCapturing {
    let gate: AdmissionCaptureGate
    let probe: AdmissionCaptureProbe
    func capture(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                 relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget, resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        await gate.block()
        return try await probe.capture(reference: reference, rootURL: rootURL, rootID: rootID,
            relativePath: relativePath, budget: budget, resources: resources)
    }
}
private final class GraphAdmissionClock: PDKAdmissionExecutionClock {
    private let instant = Mutex(ContinuousClock.now)
    func now() -> ContinuousClock.Instant { instant.withLock { $0 } }
    func expire() { instant.withLock { $0 += .seconds(20) } }
}
private struct LateDeadlineInspector: PDKProfileSourceInspecting {
    let clock: GraphAdmissionClock
    func inspect(_ request: PDKProfileSourceInspectionRequest, dependencies: any PDKProfileDependencyResolving,
                 resources: any PDKAdmissionResourceAccounting) async throws(PDKProfileInspectionError) -> PDKProfileSourceFacts {
        let facts = try await AdmissionScriptInspector(edges: []).inspect(request, dependencies: dependencies, resources: resources)
        clock.expire(); return facts
    }
}

@Suite(.timeLimit(.minutes(1)))
struct AdmissionLifecycleTests {
    @Test func anInflightContentAliasJoinsTheOriginalStructuredAcquisition() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget)
        defer { resources.close() }
        let gate = AdmissionCaptureGate(), probe = AdmissionCaptureProbe()
        var registry: PDKProfileSourceRegistry? = PDKProfileSourceRegistry(capture: GatedAdmissionCapture(gate: gate, probe: probe), resources: resources)
        let alias = try ArtifactReference(digest: fixture.rootReference.digest, byteCount: fixture.rootReference.byteCount,
            descriptor: ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: "pdk.model"), format: .spice))
        try await withThrowingTaskGroup(of: CapturedPDKSource.self) { group in
            let active = try #require(registry)
            let binding = fixture.request.sources[0]
            group.addTask { try await active.acquire(reference: fixture.rootReference, rootURL: fixture.root,
                rootID: binding.rootID, relativePath: binding.relativePath, budget: binding.budget) }
            await gate.waitUntilEntered()
            group.addTask { try await active.acquire(reference: alias, rootURL: fixture.root,
                rootID: binding.rootID, relativePath: binding.relativePath, budget: binding.budget) }
            while await active.waitingCount() == 0 { await Task.yield() }
            await gate.release()
            let first = try #require(try await group.next()), second = try #require(try await group.next())
            #expect(first.reference.id == second.reference.id)
            #expect(first.reference.descriptor != second.reference.descriptor)
            #expect(probe.references.count == 1)
            #expect(resources.used(.readBytes) == fixture.rootReference.byteCount)
            #expect(resources.used(.uniqueSources) == 1)
        }
        registry = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.openResources) == 0)
        #expect(resources.used(.concurrentAcquisitions) == 0)
    }
    @Test func cancelledAdmissionJoinsItsAcquisitionAndClosesResourceAdmission() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let gate = AdmissionCaptureGate(), probe = AdmissionCaptureProbe()
        do {
            try await withThrowingTaskGroup(of: AdmittedPDKProfile.self) { group in
                let inspector = try AdmissionScriptInspector(edges: []).registration()
                group.addTask { try await LocalPDKProfileAdmitter(inspectors: [inspector],
                    capture: GatedAdmissionCapture(gate: gate, probe: probe)).admit(fixture.request) }
                await gate.waitUntilEntered(); group.cancelAll(); await gate.release()
                _ = try await group.next()
            }
            Issue.record("Cancelled admission published a value")
        } catch let error as PDKProfileAdmissionError { #expect(error.isCancellation) }
        let resources = try #require(probe.resources)
        #expect(throws: PDKAdmissionResourceError.closed) { try resources.check() }
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.openResources) == 0)
    }
    @Test func lateProviderSuccessCannotResetTheInvocationDeadline() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let clock = GraphAdmissionClock(), probe = AdmissionCaptureProbe()
        let provider = try PDKProfileInspectorRegistration(format: .spice, parserIdentity: "fixture.parser",
            policyIdentity: "policy.v1", inspector: LateDeadlineInspector(clock: clock))
        do {
            _ = try await LocalPDKProfileAdmitter(inspectors: [provider], capture: probe, clock: clock).admit(fixture.request)
            Issue.record("A late successful provider published admission")
        } catch let error as PDKProfileAdmissionError { #expect(error == .resource(.deadlineExceeded)) }
        #expect(probe.resources?.used(.liveOwnedBytes) == 0)
        #expect(probe.resources?.used(.openResources) == 0)
    }
    @Test func copiedInputDerivedFailureRetainsItsExactDecodedBacking() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let target = fixture.root.appending(path: "root.sp")
        var bytes = try Data(contentsOf: target); bytes[0] ^= 1; try bytes.write(to: target)
        let probe = AdmissionCaptureProbe()
        var retained: PDKProfileAdmissionError?
        do {
            _ = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: []).registration()], capture: probe).admit(fixture.request)
            Issue.record("Changed source was admitted")
        } catch let error as PDKProfileAdmissionError {
            retained = error
            guard case .retained = error else { Issue.record("Derived failure lost its owner"); return }
            guard case .source(.digestMismatch) = error.underlyingReason else { Issue.record("Typed failure reason changed"); return }
            #expect(!error.isCancellation)
        }
        var copy = retained
        let resources = try #require(probe.resources)
        let held = resources.used(.liveOwnedBytes)
        #expect(held > 0)
        #expect(throws: PDKAdmissionResourceError.closed) { try resources.check() }
        retained = nil
        #expect(copy != nil)
        #expect(resources.used(.liveOwnedBytes) == held)
        copy = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.openResources) == 0)
    }
}
