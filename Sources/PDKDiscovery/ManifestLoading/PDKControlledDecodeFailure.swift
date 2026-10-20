import PDKCore

/// Retain this complete failure, including copies, while inspecting its cause.
/// Detaching the cause or its String subvalues transfers storage responsibility
/// to the caller, just as detaching a decoded success value does.
public struct PDKControlledDecodeFailure: Error, Sendable {
    public let cause: PDKBoundedDecodeError
    private let reservations: [PDKAdmissionReservation]

    internal init(cause: PDKBoundedDecodeError, reservations: consuming [PDKAdmissionReservation]) {
        self.cause = cause
        self.reservations = reservations
    }
}
