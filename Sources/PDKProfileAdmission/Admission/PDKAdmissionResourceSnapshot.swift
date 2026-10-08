/// Immutable native accounting evidence, distinct from a successful admission check.
public struct PDKAdmissionResourceSnapshot: Sendable, Equatable {
    public let accountingVersion: Int
    public let maximumElapsedNanoseconds: UInt64
    public let elapsed: Duration
    public let isDeadlineExceeded: Bool
    public let isClosed: Bool
    /// Exactly one entry per Core dimension, in declaration order.
    public let dimensions: [PDKAdmissionResourceObservation]

    internal init(accountingVersion: Int, maximumElapsedNanoseconds: UInt64,
                  elapsed: Duration, isDeadlineExceeded: Bool, isClosed: Bool,
                  dimensions: [PDKAdmissionResourceObservation]) {
        self.accountingVersion = accountingVersion
        self.maximumElapsedNanoseconds = maximumElapsedNanoseconds
        self.elapsed = elapsed
        self.isDeadlineExceeded = isDeadlineExceeded
        self.isClosed = isClosed
        self.dimensions = dimensions
    }
}
