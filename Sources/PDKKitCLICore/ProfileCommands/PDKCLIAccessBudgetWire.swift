import CircuiteFoundation
import PDKCore

struct PDKCLIAccessBudgetWire: Codable, Sendable {
    let value: ArtifactAccessBudget
    init(_ value: ArtifactAccessBudget) { self.value = value }
    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, maximumPageByteCount, maximumTotalByteCount, maximumPageCount
        case maximumWorkUnitCount, maximumDurationNanoseconds
    }
    init(from decoder: any Decoder) throws {
        let resources = try PDKCLIInputCoding.resources(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try PDKCLIInputCoding.check(c, fields: CodingKeys.allCases)
        try PDKCLIInputCoding.work(resources, 5)
        value = try ArtifactAccessBudget(maximumPageByteCount: c.decode(UInt64.self, forKey: .maximumPageByteCount),
            maximumTotalByteCount: c.decode(UInt64.self, forKey: .maximumTotalByteCount),
            maximumPageCount: c.decode(UInt64.self, forKey: .maximumPageCount),
            maximumWorkUnitCount: c.decode(UInt64.self, forKey: .maximumWorkUnitCount),
            maximumDurationNanoseconds: c.decode(UInt64.self, forKey: .maximumDurationNanoseconds))
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion)
        try c.encode(value.maximumPageByteCount, forKey: .maximumPageByteCount)
        try c.encode(value.maximumTotalByteCount, forKey: .maximumTotalByteCount)
        try c.encode(value.maximumPageCount, forKey: .maximumPageCount)
        try c.encode(value.maximumWorkUnitCount, forKey: .maximumWorkUnitCount)
        try c.encode(value.maximumDurationNanoseconds, forKey: .maximumDurationNanoseconds)
    }
}
