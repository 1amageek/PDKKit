import PDKCore
import Synchronization

final class BoundedCaptureTestAccounting: PDKAdmissionResourceAccounting {
    private struct State {
        var failure: PDKAdmissionResourceError?
        var limits: [PDKAdmissionResourceDimension: UInt64] = [:]
        var used: [PDKAdmissionResourceDimension: UInt64] = [:]
        var peak: [PDKAdmissionResourceDimension: UInt64] = [:]
    }
    private let state = Mutex(State())
    var failure: PDKAdmissionResourceError? {
        get { state.withLock { $0.failure } }
        set { state.withLock { $0.failure = newValue } }
    }
    func limit(_ dimension: PDKAdmissionResourceDimension, to amount: UInt64) { state.withLock { $0.limits[dimension] = amount } }
    func used(_ dimension: PDKAdmissionResourceDimension) -> UInt64 { state.withLock { $0.used[dimension, default: 0] } }
    func peak(_ dimension: PDKAdmissionResourceDimension) -> UInt64 { state.withLock { $0.peak[dimension, default: 0] } }
    func check() throws(PDKAdmissionResourceError) {
        if let error = state.withLock({ $0.failure }) { throw error }
    }
    func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
        let error: PDKAdmissionResourceError? = state.withLock {
            if let failure = $0.failure { return failure }
            let (next, overflow) = $0.used[cost.dimension, default: 0].addingReportingOverflow(cost.amount)
            if overflow { return .arithmeticOverflow(cost.dimension) }
            let limit = $0.limits[cost.dimension, default: UInt64.max]
            if next > limit { return .exhausted(dimension: cost.dimension, limit: limit, attempted: next) }
            $0.used[cost.dimension] = next
            $0.peak[cost.dimension] = max(next, $0.peak[cost.dimension, default: 0])
            return nil
        }
        if let error { throw error }
        return PDKAdmissionReservation(cost: cost) { [self] in
            guard cost.dimension.isLiveCapacity else { return }
            state.withLock { $0.used[cost.dimension, default: 0] -= cost.amount }
        }
    }
}
