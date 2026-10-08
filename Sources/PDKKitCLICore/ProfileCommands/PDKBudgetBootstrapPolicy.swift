/// Host bootstrap capacity, independent of the invocation's semantic budget.
public struct PDKBudgetBootstrapPolicy: Sendable, Hashable {
    public let maximumByteCount: UInt64
    /// Verified escaped schema capacity (2,524 bytes) plus finite whitespace.
    public static let standard = Self(checkedMaximumByteCount: 16_384)
    public init(maximumByteCount: UInt64) throws(PDKBudgetBootstrapError) {
        guard maximumByteCount > 0, maximumByteCount <= UInt64(Int.max) else { throw .invalidPolicy }
        self.maximumByteCount = maximumByteCount
    }
    private init(checkedMaximumByteCount: UInt64) { maximumByteCount = checkedMaximumByteCount }
}
