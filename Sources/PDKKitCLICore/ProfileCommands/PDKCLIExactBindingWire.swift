import CircuiteFoundation
import CircuiteFoundationFoundation
import PDKProfileAdmission

struct PDKCLIExactBindingWire: Codable, Sendable {
    let value: PDKProfileExactBinding
    init(_ value: PDKProfileExactBinding) { self.value = value }
    enum CodingKeys: String, CodingKey, CaseIterable { case schemaVersion, reference, rootID, relativePath, budget }
    init(from decoder: any Decoder) throws {
        let resources = try PDKCLIInputCoding.resources(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try PDKCLIInputCoding.check(c, fields: CodingKeys.allCases)
        let reference = try c.decode(ArtifactReference.self, forKey: .reference)
        let rootID = try c.decode(String.self, forKey: .rootID)
        let segments = try c.decode([String].self, forKey: .relativePath)
        let budget = try c.decode(PDKCLIAccessBudgetWire.self, forKey: .budget)
        try PDKCLIInputCoding.id(rootID, resources: resources)
        for segment in segments { try PDKCLIInputCoding.work(resources, UInt64(segment.utf8.count) + 1) }
        value = .init(reference: reference, rootID: try ArtifactRootID(rawValue: rootID),
            relativePath: try ArtifactRelativePath(segments: segments), budget: budget.value)
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion); try c.encode(value.reference, forKey: .reference)
        try c.encode(value.rootID.rawValue, forKey: .rootID)
        try c.encode(value.relativePath.segments, forKey: .relativePath)
        try c.encode(PDKCLIAccessBudgetWire(value.budget), forKey: .budget)
    }
}
