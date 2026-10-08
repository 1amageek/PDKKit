public enum PDKAdmissionResourceError: Error, Sendable, Equatable {
    case unsupportedAccountingVersion(Int)
    case invalidCost
    case arithmeticOverflow(PDKAdmissionResourceDimension)
    case exhausted(dimension: PDKAdmissionResourceDimension, limit: UInt64, attempted: UInt64)
    case deadlineExceeded
    case cancelled
    case closed
    case unsupportedBudgetCapability(String)
}
