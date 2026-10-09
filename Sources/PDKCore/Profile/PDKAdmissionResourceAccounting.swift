public protocol PDKAdmissionResourceAccounting: Sendable {
    /// Admit cumulative work before performing it, without retaining a release handle.
    func charge(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError)
    /// Reserve before performing work or growing live storage. Cumulative work is never refunded.
    func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation
    /// Check the one invocation deadline and cancellation state, including before publication.
    func check() throws(PDKAdmissionResourceError)
}

public extension PDKAdmissionResourceAccounting {
    func charge(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) {
        guard !cost.dimension.isLiveCapacity else { throw .invalidCost }
        _ = try reserve(cost)
    }
}
