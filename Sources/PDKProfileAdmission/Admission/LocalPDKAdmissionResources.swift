import PDKCore
import Synchronization

/// One invocation's cumulative work and retained live capacity.
public final class LocalPDKAdmissionResources: PDKAdmissionResourceAccounting, PDKAdmissionResourceObserving {
    public let budget: PDKAdmissionBudget
    private let clock: any PDKAdmissionExecutionClock
    private let started: ContinuousClock.Instant
    private let maximumElapsed: Duration
    private let state: Mutex<State>

    private struct State {
        var closed = false
        var used = [UInt64](repeating: 0, count: PDKAdmissionResourceDimension.allCases.count)
        var peaks = [UInt64](repeating: 0, count: PDKAdmissionResourceDimension.allCases.count)
    }

    public init(budget: PDKAdmissionBudget,
                clock: any PDKAdmissionExecutionClock = SystemPDKAdmissionExecutionClock()) {
        self.budget = budget
        self.clock = clock
        self.started = clock.now()
        self.maximumElapsed = .seconds(Int64(budget.maximumElapsedNanoseconds / 1_000_000_000))
            + .nanoseconds(Int64(budget.maximumElapsedNanoseconds % 1_000_000_000))
        self.state = Mutex(State())
    }

    public func check() throws(PDKAdmissionResourceError) {
        let now = clock.now()
        let cancelled = Task.isCancelled
        try state.withLock { (state) throws(PDKAdmissionResourceError) in
            try validate(state, now: now, cancelled: cancelled)
        }
    }

    public func charge(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) {
        guard !cost.dimension.isLiveCapacity else { throw .invalidCost }
        try admit(cost)
    }

    private func admit(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) {
        let now = clock.now()
        let cancelled = Task.isCancelled
        let index = Self.index(cost.dimension)
        try state.withLock { (state) throws(PDKAdmissionResourceError) in
            try validate(state, now: now, cancelled: cancelled)
            guard cost.accountingVersion == budget.accountingVersion else {
                throw .unsupportedAccountingVersion(cost.accountingVersion)
            }
            let (attempted, overflow) = state.used[index].addingReportingOverflow(cost.amount)
            guard !overflow else { throw .arithmeticOverflow(cost.dimension) }
            guard let limit = budget.limits[cost.dimension] else {
                throw .unsupportedBudgetCapability("Checked budget is missing a resource dimension")
            }
            guard attempted <= limit else {
                throw .exhausted(dimension: cost.dimension, limit: limit, attempted: attempted)
            }
            state.used[index] = attempted
            if cost.dimension.isLiveCapacity {
                state.peaks[index] = max(state.peaks[index], attempted)
            }
        }
    }

    public func reserve(_ cost: PDKAdmissionCost)
        throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
        try admit(cost)
        let index = Self.index(cost.dimension)
        return PDKAdmissionReservation(cost: cost) { [self] in
            guard cost.dimension.isLiveCapacity else { return }
            state.withLock { state in
                // Only the exactly-once Core owner invokes this release action.
                precondition(state.used[index] >= cost.amount, "Reservation release exceeds retained capacity")
                state.used[index] -= cost.amount
            }
        }
    }

    /// Rejects new work while allowing already retained owners to release.
    public func close() { state.withLock { $0.closed = true } }

    public func snapshot() throws(PDKAdmissionResourceError) -> PDKAdmissionResourceSnapshot {
        let now = clock.now()
        guard now >= started else {
            throw .unsupportedBudgetCapability("Admission clock moved backwards")
        }
        let elapsed = now - started
        return state.withLock { state in
            let dimensions = PDKAdmissionResourceDimension.allCases.map { dimension in
                let index = Self.index(dimension)
                let usage: PDKAdmissionResourceObservation.Usage = dimension.isLiveCapacity
                    ? .live(current: state.used[index], peak: state.peaks[index])
                    : .cumulative(total: state.used[index])
                return PDKAdmissionResourceObservation(dimension: dimension,
                    limit: budget.limits[dimension]!, usage: usage)
            }
            return PDKAdmissionResourceSnapshot(accountingVersion: budget.accountingVersion,
                maximumElapsedNanoseconds: budget.maximumElapsedNanoseconds, elapsed: elapsed,
                isDeadlineExceeded: elapsed >= maximumElapsed, isClosed: state.closed,
                dimensions: dimensions)
        }
    }

    internal func used(_ dimension: PDKAdmissionResourceDimension) -> UInt64 {
        state.withLock { $0.used[Self.index(dimension)] }
    }

    private func validate(_ state: borrowing State, now: ContinuousClock.Instant, cancelled: Bool)
        throws(PDKAdmissionResourceError) {
        guard !state.closed else { throw .closed }
        guard !cancelled else { throw .cancelled }
        guard now >= started else {
            throw .unsupportedBudgetCapability("Admission clock moved backwards")
        }
        guard now - started < maximumElapsed else { throw .deadlineExceeded }
    }

    private static func index(_ dimension: PDKAdmissionResourceDimension) -> Int {
        switch dimension {
        case .searchRoots: 0
        case .scannedEntries: 1
        case .candidates: 2
        case .readBytes: 3
        case .hashedBytes: 4
        case .uniqueSources: 5
        case .pages: 6
        case .contextualNodes: 7
        case .dependencyEdges: 8
        case .includeDepth: 9
        case .expansions: 10
        case .decodedElements: 11
        case .decodeNesting: 12
        case .scalarBytes: 13
        case .parserWork: 14
        case .liveOwnedBytes: 15
        case .temporaryBytes: 16
        case .concurrentAcquisitions: 17
        case .openResources: 18
        case .diagnosticEntries: 19
        case .diagnosticBytes: 20
        }
    }
}
