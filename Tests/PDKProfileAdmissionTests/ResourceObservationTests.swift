import PDKCore
@testable import PDKProfileAdmission
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ResourceObservationTests {
    private final class Clock: PDKAdmissionExecutionClock {
        let instant = Mutex(ContinuousClock.now)
        let onSample = Mutex<(@Sendable () -> Void)?>(nil)
        func now() -> ContinuousClock.Instant {
            let callback = onSample.withLock { $0 }
            callback?()
            return instant.withLock { $0 }
        }
        func advance(_ amount: Duration) { instant.withLock { $0 = $0.advanced(by: amount) } }
    }

    private actor Gate {
        let expected: Int
        var waiters: [CheckedContinuation<Void, Never>] = []
        init(expected: Int) { self.expected = expected }
        func wait() async {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
                if waiters.count == expected {
                    let ready = waiters
                    waiters.removeAll()
                    for waiter in ready { waiter.resume() }
                }
            }
        }
    }

    private func budget(limit: UInt64 = 100, elapsed: UInt64 = UInt64.max) throws -> PDKAdmissionBudget {
        try PDKAdmissionBudget(limits: Dictionary(uniqueKeysWithValues:
            PDKAdmissionResourceDimension.allCases.map { ($0, limit) }), maximumElapsedNanoseconds: elapsed)
    }

    private func usage(_ snapshot: PDKAdmissionResourceSnapshot, _ dimension: PDKAdmissionResourceDimension)
        throws -> PDKAdmissionResourceObservation.Usage {
        try #require(snapshot.dimensions.first { $0.dimension == dimension }).usage
    }

    @Test func protocolSnapshotPreservesTheCompleteConfiguredVocabularyAndReleasePolicies() throws {
        let clock = Clock()
        let configured = try budget()
        let resources = LocalPDKAdmissionResources(budget: configured, clock: clock)
        let observer: any PDKAdmissionResourceObserving = resources
        var held: [PDKAdmissionReservation] = []
        for (index, dimension) in PDKAdmissionResourceDimension.allCases.enumerated() {
            held.append(try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: UInt64(index + 1))))
        }
        let before = try observer.snapshot()
        #expect(before.dimensions.map(\.dimension) == PDKAdmissionResourceDimension.allCases)
        #expect(before.accountingVersion == configured.accountingVersion)
        #expect(before.maximumElapsedNanoseconds == configured.maximumElapsedNanoseconds)
        #expect(before.elapsed == .zero)
        #expect(!before.isClosed && !before.isDeadlineExceeded)
        for (index, entry) in before.dimensions.enumerated() {
            let amount = UInt64(index + 1)
            #expect(entry.limit == configured.limits[entry.dimension])
            #expect(entry.usage == (entry.dimension.isLiveCapacity
                ? .live(current: amount, peak: amount) : .cumulative(total: amount)))
        }
        held.removeAll()
        let after = try observer.snapshot()
        for (index, entry) in after.dimensions.enumerated() {
            let amount = UInt64(index + 1)
            #expect(entry.usage == (entry.dimension.isLiveCapacity
                ? .live(current: 0, peak: amount) : .cumulative(total: amount)))
        }
        #expect(before != after)
        #expect(try observer.snapshot() == after)
    }

    @Test func retainedCopyReleasesCurrentAfterCloseWithoutErasingPeakOrCumulativeWork() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget(limit: 8))
        var copied: PDKAdmissionReservation?
        do {
            let receipt = try resources.reserve(PDKAdmissionCost(dimension: .liveOwnedBytes, amount: 8))
            copied = receipt
            _ = try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 3))
        }
        resources.close()
        let held = try resources.snapshot()
        #expect(held.isClosed)
        #expect(try usage(held, .liveOwnedBytes) == .live(current: 8, peak: 8))
        #expect(throws: PDKAdmissionResourceError.closed) { try resources.check() }
        copied = nil
        let released = try resources.snapshot()
        #expect(released.isClosed)
        #expect(try usage(released, .liveOwnedBytes) == .live(current: 0, peak: 8))
        #expect(try usage(released, .readBytes) == .cumulative(total: 3))
        #expect(try usage(held, .liveOwnedBytes) == .live(current: 8, peak: 8))
        withExtendedLifetime(copied) {}
    }

    @Test(arguments: PDKAdmissionResourceDimension.allCases)
    func refusedReservationPreservesEveryObservedCounterAndPeak(dimension: PDKAdmissionResourceDimension) throws {
        let clock = Clock()
        let resources = LocalPDKAdmissionResources(budget: try budget(limit: 8), clock: clock)
        let held = try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: 8))
        let before = try resources.snapshot()
        #expect(throws: PDKAdmissionResourceError.exhausted(dimension: dimension, limit: 8, attempted: 9)) {
            try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: 1))
        }
        #expect(try resources.snapshot() == before)
        withExtendedLifetime(held) {}
    }

    @Test func overflowRefusalDoesNotRaisePeak() throws {
        let clock = Clock()
        let resources = LocalPDKAdmissionResources(budget: try budget(limit: UInt64.max), clock: clock)
        let held = try resources.reserve(PDKAdmissionCost(dimension: .temporaryBytes, amount: UInt64.max))
        let before = try resources.snapshot()
        #expect(throws: PDKAdmissionResourceError.arithmeticOverflow(.temporaryBytes)) {
            try resources.reserve(PDKAdmissionCost(dimension: .temporaryBytes, amount: 1))
        }
        #expect(try resources.snapshot() == before)
        #expect(try usage(before, .temporaryBytes) == .live(current: UInt64.max, peak: UInt64.max))
        withExtendedLifetime(held) {}
    }

    @Test func elapsedSnapshotPreservesExactDeadlineAndBackwardClockFailureAfterClose() throws {
        let clock = Clock()
        let resources = LocalPDKAdmissionResources(budget: try budget(elapsed: 100), clock: clock)
        clock.advance(.nanoseconds(60))
        let early = try resources.snapshot()
        #expect(early.elapsed == .nanoseconds(60))
        #expect(!early.isDeadlineExceeded)
        _ = try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 1))
        clock.advance(.nanoseconds(40))
        let expired = try resources.snapshot()
        #expect(expired.elapsed == .nanoseconds(100) && expired.isDeadlineExceeded)
        #expect(throws: PDKAdmissionResourceError.deadlineExceeded) { try resources.check() }
        resources.close()
        clock.advance(.nanoseconds(50))
        let closed = try resources.snapshot()
        #expect(closed.elapsed == .nanoseconds(150) && closed.isDeadlineExceeded && closed.isClosed)
        #expect(try usage(closed, .readBytes) == .cumulative(total: 1))
        clock.advance(.nanoseconds(-151))
        #expect(throws: PDKAdmissionResourceError.unsupportedBudgetCapability("Admission clock moved backwards")) {
            try resources.snapshot()
        }
    }

    @Test func cancelledObservationDoesNotAuthorizeWorkOrResetCharges() async throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        _ = try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 4))
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                withUnsafeCurrentTask { $0?.cancel() }
                let observed = try resources.snapshot()
                #expect(try usage(observed, .readBytes) == .cumulative(total: 4))
                #expect(throws: PDKAdmissionResourceError.cancelled) { try resources.check() }
                #expect(throws: PDKAdmissionResourceError.cancelled) {
                    try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 1))
                }
                resources.close()
                #expect(try resources.snapshot().isClosed)
            }
            try await group.waitForAll()
        }
    }

    @Test func clockCanReenterAccountingWithoutRunningUnderItsMutex() throws {
        let clock = Clock()
        let resources = LocalPDKAdmissionResources(budget: try budget(), clock: clock)
        clock.onSample.withLock { $0 = { #expect(resources.used(.readBytes) == 0) } }
        defer { clock.onSample.withLock { $0 = nil } }
        #expect(try resources.snapshot().elapsed == .zero)
    }

    @Test func simultaneousReserveReleaseAndSnapshotsPreserveAtomicLivePeaks() async throws {
        let resources = LocalPDKAdmissionResources(budget: try budget(limit: 32))
        let cost = try PDKAdmissionCost(dimension: .liveOwnedBytes, amount: 1)
        let gate = Gate(expected: 32)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    do {
                        let owner = try resources.reserve(cost)
                        await gate.wait()
                        let held = try resources.snapshot()
                        guard case .live(let current, let peak) = try usage(held, .liveOwnedBytes) else {
                            Issue.record("Live observation was reported as cumulative"); return
                        }
                        #expect(current > 0 && current <= 32 && peak == 32)
                        withExtendedLifetime(owner) {}
                    }
                    let released = try resources.snapshot()
                    guard case .live(let current, let peak) = try usage(released, .liveOwnedBytes) else {
                        Issue.record("Live observation was reported as cumulative"); return
                    }
                    #expect(current <= peak && peak == 32)
                }
            }
            try await group.waitForAll()
        }
        #expect(try usage(resources.snapshot(), .liveOwnedBytes) == .live(current: 0, peak: 32))
    }
}
