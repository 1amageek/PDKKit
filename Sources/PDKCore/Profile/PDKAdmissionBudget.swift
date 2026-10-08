import Foundation

/// Invocation limits. Host composition selects policy; these limits never enter semantic identity.
public struct PDKAdmissionBudget: Sendable, Hashable, Codable {
    public let accountingVersion: Int
    public let limits: [PDKAdmissionResourceDimension: UInt64]
    public let maximumElapsedNanoseconds: UInt64
    public init(accountingVersion: Int = PDKAdmissionCost.currentAccountingVersion,
                limits: [PDKAdmissionResourceDimension: UInt64], maximumElapsedNanoseconds: UInt64) throws(PDKProfileValueError) {
        guard accountingVersion == PDKAdmissionCost.currentAccountingVersion else { throw .invalidBudget("accountingVersion") }
        guard maximumElapsedNanoseconds > 0,
              Set(limits.keys) == Set(PDKAdmissionResourceDimension.allCases),
              limits.values.allSatisfy({ $0 > 0 }) else { throw .invalidBudget("positive complete limits required") }
        self.accountingVersion = accountingVersion; self.limits = limits; self.maximumElapsedNanoseconds = maximumElapsedNanoseconds
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, accountingVersion, limits, maximumElapsedNanoseconds }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["accountingVersion", "limits", "maximumElapsedNanoseconds"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(accountingVersion: c.decode(Int.self, forKey: .accountingVersion),
            limits: c.decode([PDKAdmissionResourceDimension: UInt64].self, forKey: .limits),
            maximumElapsedNanoseconds: c.decode(UInt64.self, forKey: .maximumElapsedNanoseconds))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion); try c.encode(accountingVersion, forKey: .accountingVersion)
        try c.encode(limits, forKey: .limits); try c.encode(maximumElapsedNanoseconds, forKey: .maximumElapsedNanoseconds)
    }
}
