public protocol PDKAdmissionResourceAccounting: Sendable {
    /// Reserve before performing work or growing live storage. Cumulative work is never refunded.
    func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation
    /// Check the one invocation deadline and cancellation state, including before publication.
    func check() throws(PDKAdmissionResourceError)
}
