public struct PDKAdmissionCost: Sendable, Hashable {
    public static let currentAccountingVersion = 1
    public let accountingVersion: Int
    public let dimension: PDKAdmissionResourceDimension
    public let amount: UInt64
    public init(accountingVersion: Int = Self.currentAccountingVersion,
                dimension: PDKAdmissionResourceDimension, amount: UInt64) throws(PDKAdmissionResourceError) {
        guard accountingVersion == Self.currentAccountingVersion else { throw .unsupportedAccountingVersion(accountingVersion) }
        guard amount > 0 else { throw .invalidCost }
        self.accountingVersion = accountingVersion; self.dimension = dimension; self.amount = amount
    }
}
