import PDKCore
@testable import PDKProfileAdmission
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ResourceAccountingTests {
    private final class Clock: PDKAdmissionExecutionClock {
        let instant = Mutex(ContinuousClock.now)
        func now() -> ContinuousClock.Instant { instant.withLock { $0 } }
        func advance(_ amount: Duration) { instant.withLock { $0 = $0.advanced(by: amount) } }
    }

    private actor Gate {
        private let expected: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []
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

    private final class ReceiptAccounting: PDKAdmissionResourceAccounting {
        let calls = Mutex((reserved: 0, released: 0))
        func check() throws(PDKAdmissionResourceError) {}
        func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
            calls.withLock { $0.reserved += 1 }
            return PDKAdmissionReservation(cost: cost) { [self] in
                calls.withLock { $0.released += 1 }
            }
        }
    }

    private func budget(_ overrides: [PDKAdmissionResourceDimension: UInt64] = [:],
                        elapsed: UInt64 = UInt64.max) throws -> PDKAdmissionBudget {
        var limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64.max) })
        for (key, value) in overrides { limits[key] = value }
        return try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: elapsed)
    }

    @Test(arguments: PDKAdmissionResourceDimension.allCases)
    func everyDimensionEnforcesItsExactBoundary(dimension: PDKAdmissionResourceDimension) throws {
        let resources = LocalPDKAdmissionResources(budget: try budget([dimension: 8]))
        let first = try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: 4))
        let second = try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: 4))
        #expect(resources.used(dimension) == 8)
        #expect(throws: PDKAdmissionResourceError.exhausted(dimension: dimension, limit: 8, attempted: 9)) {
            try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: 1))
        }
        #expect(resources.used(dimension) == 8)
        withExtendedLifetime((first, second)) {}
    }

    @Test func copiedLiveReservationReleasesOnlyAtTheLastOwner() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget([.liveOwnedBytes: 8]))
        var copied: PDKAdmissionReservation?
        do {
            let lease = try resources.reserve(PDKAdmissionCost(dimension: .liveOwnedBytes, amount: 8))
            copied = lease
        }
        #expect(resources.used(.liveOwnedBytes) == 8)
        resources.close()
        copied = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
        withExtendedLifetime(copied) {}
    }

    @Test func cumulativeWorkIsNeverRefunded() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget([.readBytes: 8]))
        do { let lease = try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 8)); withExtendedLifetime(lease) {} }
        #expect(resources.used(.readBytes) == 8)
        #expect(throws: PDKAdmissionResourceError.exhausted(dimension: .readBytes, limit: 8, attempted: 9)) {
            try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 1))
        }
    }

    @Test(arguments: PDKAdmissionResourceDimension.allCases)
    func chargingKeepsExactCumulativeBoundariesAndRejectsLiveDimensions(dimension: PDKAdmissionResourceDimension) throws {
        let resources = LocalPDKAdmissionResources(budget: try budget([dimension: 8]))
        let accounting: any PDKAdmissionResourceAccounting = resources
        let cost = try PDKAdmissionCost(dimension: dimension, amount: 4)
        if dimension.isLiveCapacity {
            #expect(throws: PDKAdmissionResourceError.invalidCost) { try accounting.charge(cost) }
            #expect(resources.used(dimension) == 0)
            return
        }
        try accounting.charge(cost)
        _ = try accounting.reserve(cost)
        #expect(resources.used(dimension) == 8)
        #expect(throws: PDKAdmissionResourceError.exhausted(dimension: dimension, limit: 8, attempted: 9)) {
            try accounting.charge(PDKAdmissionCost(dimension: dimension, amount: 1))
        }
        #expect(resources.used(dimension) == 8)
    }

    @Test func defaultChargeUsesInjectedReservationAndReleasePolicy() throws {
        let owner = ReceiptAccounting()
        let accounting: any PDKAdmissionResourceAccounting = owner
        try accounting.charge(PDKAdmissionCost(dimension: .parserWork, amount: 1))
        #expect(owner.calls.withLock { $0.reserved == 1 && $0.released == 1 })
        #expect(throws: PDKAdmissionResourceError.invalidCost) {
            try accounting.charge(PDKAdmissionCost(dimension: .temporaryBytes, amount: 1))
        }
        #expect(owner.calls.withLock { $0.reserved == 1 && $0.released == 1 })
    }

    @Test func cumulativeChargeOverflowLeavesTheCounterUnchanged() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        try resources.charge(PDKAdmissionCost(dimension: .parserWork, amount: UInt64.max))
        #expect(throws: PDKAdmissionResourceError.arithmeticOverflow(.parserWork)) {
            try resources.charge(PDKAdmissionCost(dimension: .parserWork, amount: 1))
        }
        #expect(resources.used(.parserWork) == UInt64.max)
    }

    @Test func dimensionsKeepIndependentCountersAndReleasePolicies() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        var held: [PDKAdmissionReservation] = []
        for (index, dimension) in PDKAdmissionResourceDimension.allCases.enumerated() {
            held.append(try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: UInt64(index + 1))))
        }
        for (index, dimension) in PDKAdmissionResourceDimension.allCases.enumerated() {
            #expect(resources.used(dimension) == UInt64(index + 1))
        }
        held.removeAll()
        for (index, dimension) in PDKAdmissionResourceDimension.allCases.enumerated() {
            #expect(resources.used(dimension) == (dimension.isLiveCapacity ? 0 : UInt64(index + 1)))
        }
    }

    @Test func overflowDoesNotMutateTheCounter() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        let lease = try resources.reserve(PDKAdmissionCost(dimension: .temporaryBytes, amount: UInt64.max))
        #expect(throws: PDKAdmissionResourceError.arithmeticOverflow(.temporaryBytes)) {
            try resources.reserve(PDKAdmissionCost(dimension: .temporaryBytes, amount: 1))
        }
        #expect(resources.used(.temporaryBytes) == UInt64.max)
        withExtendedLifetime(lease) {}
    }

    @Test func oneDeadlineIsNotResetByReservations() throws {
        let clock = Clock()
        let resources = LocalPDKAdmissionResources(budget: try budget(elapsed: 100), clock: clock)
        clock.advance(.nanoseconds(60))
        _ = try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 1))
        clock.advance(.nanoseconds(40))
        #expect(throws: PDKAdmissionResourceError.deadlineExceeded) { try resources.check() }
        #expect(throws: PDKAdmissionResourceError.deadlineExceeded) {
            try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 1))
        }
        #expect(resources.used(.readBytes) == 1)
        #expect(throws: PDKAdmissionResourceError.deadlineExceeded) {
            try resources.charge(PDKAdmissionCost(dimension: .readBytes, amount: 1))
        }
        #expect(resources.used(.readBytes) == 1)
    }

    @Test func closedOwnerRefusesCheckAndNewCapacity() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        resources.close(); resources.close()
        #expect(throws: PDKAdmissionResourceError.closed) { try resources.check() }
        #expect(throws: PDKAdmissionResourceError.closed) {
            try resources.reserve(PDKAdmissionCost(dimension: .liveOwnedBytes, amount: 1))
        }
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(throws: PDKAdmissionResourceError.closed) {
            try resources.charge(PDKAdmissionCost(dimension: .readBytes, amount: 1))
        }
        #expect(resources.used(.readBytes) == 0)
    }

    @Test func backwardsClockIsAnExplicitCapabilityFailure() throws {
        let clock = Clock()
        let resources = LocalPDKAdmissionResources(budget: try budget(), clock: clock)
        clock.advance(.nanoseconds(-1))
        #expect(throws: PDKAdmissionResourceError.unsupportedBudgetCapability("Admission clock moved backwards")) {
            try resources.check()
        }
    }

    @Test func cancelledTaskCannotReserveOrCheck() async throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        let refused = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                withUnsafeCurrentTask { $0?.cancel() }
                do throws(PDKAdmissionResourceError) { try resources.check(); return false }
                catch { guard error == .cancelled else { return false } }
                do throws(PDKAdmissionResourceError) { try resources.charge(PDKAdmissionCost(dimension: .readBytes, amount: 1)); return false }
                catch { guard error == .cancelled else { return false } }
                do throws(PDKAdmissionResourceError) { _ = try resources.reserve(PDKAdmissionCost(dimension: .readBytes, amount: 1)); return false }
                catch { return error == .cancelled }
            }
            return await group.next() ?? false
        }
        #expect(refused)
        #expect(resources.used(.readBytes) == 0)
    }

    @Test func concurrentCumulativeReservationsCannotOverAdmit() async throws {
        let resources = LocalPDKAdmissionResources(budget: try budget([.readBytes: 8]))
        let cost = try PDKAdmissionCost(dimension: .readBytes, amount: 1)
        let admitted = await withTaskGroup(of: Bool.self) { group in
            for index in 0..<32 {
                group.addTask {
                    do throws(PDKAdmissionResourceError) {
                        if index.isMultiple(of: 2) { try resources.charge(cost) }
                        else { _ = try resources.reserve(cost) }
                        return true
                    }
                    catch { guard case .exhausted = error else { Issue.record("Unexpected concurrent refusal: \(error)"); return false }; return false }
                }
            }
            var count = 0
            for await success in group { if success { count += 1 } }
            return count
        }
        #expect(admitted == 8)
        #expect(resources.used(.readBytes) == 8)
    }

    @Test func concurrentLiveOwnersRemainChargedThroughCollectionAndThenRelease() async throws {
        let resources = LocalPDKAdmissionResources(budget: try budget([.liveOwnedBytes: 8]))
        let cost = try PDKAdmissionCost(dimension: .liveOwnedBytes, amount: 1)
        var held = await withTaskGroup(of: PDKAdmissionReservation?.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    do throws(PDKAdmissionResourceError) { return try resources.reserve(cost) }
                    catch { guard case .exhausted = error else { Issue.record("Unexpected live refusal: \(error)"); return nil }; return nil }
                }
            }
            var owners: [PDKAdmissionReservation] = []
            for await value in group { if let value { owners.append(value) } }
            return owners
        }
        #expect(held.count == 8)
        #expect(resources.used(.liveOwnedBytes) == 8)
        resources.close()
        held.removeAll()
        #expect(resources.used(.liveOwnedBytes) == 0)
    }

    @Test func closingRacesWithReservationWithoutDiscardingRetainedCapacity() async throws {
        let resources = LocalPDKAdmissionResources(budget: try budget([.liveOwnedBytes: 8]))
        let gate = Gate(expected: 32)
        let cost = try PDKAdmissionCost(dimension: .liveOwnedBytes, amount: 1)
        var owners = await withTaskGroup(of: PDKAdmissionReservation?.self) { group in
            for index in 0..<32 {
                group.addTask {
                    await gate.wait()
                    if index == 0 { resources.close(); return nil }
                    do throws(PDKAdmissionResourceError) { return try resources.reserve(cost) }
                    catch {
                        switch error {
                        case .closed, .exhausted: return nil
                        default: Issue.record("Unexpected close-race failure: \(error)"); return nil
                        }
                    }
                }
            }
            var held: [PDKAdmissionReservation] = []
            for await owner in group { if let owner { held.append(owner) } }
            return held
        }
        #expect(owners.count <= 8)
        #expect(resources.used(.liveOwnedBytes) == UInt64(owners.count))
        #expect(throws: PDKAdmissionResourceError.closed) { try resources.reserve(cost) }
        owners.removeAll()
        #expect(resources.used(.liveOwnedBytes) == 0)
    }
}
