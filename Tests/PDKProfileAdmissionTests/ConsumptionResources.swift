import PDKCore
import PDKProfileAdmission
import Synchronization

final class ConsumptionResources: PDKAdmissionResourceAccounting {
    private struct State { var checks = 0; var failAt: Int?; var failure: PDKAdmissionResourceError = .deadlineExceeded }
    private let state = Mutex(State())
    let native: LocalPDKAdmissionResources
    init(budget: PDKAdmissionBudget) { native = .init(budget: budget) }
    var checks: Int { state.withLock { $0.checks } }
    func fail(at check: Int, with failure: PDKAdmissionResourceError = .deadlineExceeded) {
        state.withLock { $0.failAt = check; $0.failure = failure }
    }
    func check() throws(PDKAdmissionResourceError) {
        let failure = state.withLock { state -> PDKAdmissionResourceError? in
            state.checks += 1; return state.checks == state.failAt ? state.failure : nil
        }
        if let failure { throw failure }; try native.check()
    }
    func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation { try native.reserve(cost) }
}
