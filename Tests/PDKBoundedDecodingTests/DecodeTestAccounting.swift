import PDKCore
import Synchronization

final class DecodeTestAccounting: PDKAdmissionResourceAccounting {
    struct State {
        var consumed: [PDKAdmissionResourceDimension: UInt64] = [:]
        var peak: [PDKAdmissionResourceDimension: UInt64] = [:]
        var checks = 0
    }
    let state = Mutex(State())
    let limits: [PDKAdmissionResourceDimension: UInt64]
    let cancelAfterChecks: Int?
    let failure: PDKAdmissionResourceError
    init(limits: [PDKAdmissionResourceDimension: UInt64] = [:], cancelAfterChecks: Int? = nil, failure: PDKAdmissionResourceError = .cancelled) {
        self.limits = limits; self.cancelAfterChecks = cancelAfterChecks; self.failure = failure
    }
    func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
        try check()
        try state.withLock { state throws(PDKAdmissionResourceError) in
            let (next, overflow) = state.consumed[cost.dimension, default: 0].addingReportingOverflow(cost.amount)
            guard !overflow else { throw .arithmeticOverflow(cost.dimension) }
            let limit = limits[cost.dimension, default: UInt64.max]
            guard next <= limit else { throw .exhausted(dimension: cost.dimension, limit: limit, attempted: next) }
            state.consumed[cost.dimension] = next
            state.peak[cost.dimension] = max(next, state.peak[cost.dimension, default: 0])
        }
        return PDKAdmissionReservation(cost: cost) { [self] in
            if cost.dimension.isLiveCapacity {
                state.withLock { $0.consumed[cost.dimension, default: 0] -= cost.amount }
            }
        }
    }
    func check() throws(PDKAdmissionResourceError) {
        try state.withLock { state throws(PDKAdmissionResourceError) in
            state.checks += 1
            if let cancelAfterChecks, state.checks >= cancelAfterChecks { throw failure }
        }
    }
    func amount(_ dimension: PDKAdmissionResourceDimension) -> UInt64 { state.withLock { $0.consumed[dimension, default: 0] } }
}
