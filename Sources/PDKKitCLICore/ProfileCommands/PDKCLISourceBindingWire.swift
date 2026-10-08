import CircuiteFoundation
import PDKProfileAdmission

struct PDKCLISourceBindingWire: Codable, Sendable {
    let value: PDKProfileSourceBinding
    init(_ value: PDKProfileSourceBinding) { self.value = value }
    enum CodingKeys: String, CodingKey, CaseIterable { case schemaVersion, sourceKey, logicalRoute, rootID, relativePath, budget }
    init(from decoder: any Decoder) throws {
        let resources = try PDKCLIInputCoding.resources(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try PDKCLIInputCoding.check(c, fields: CodingKeys.allCases)
        let key = try c.decode(String.self, forKey: .sourceKey)
        let route = try c.decode(String.self, forKey: .logicalRoute)
        let root = try c.decode(String.self, forKey: .rootID)
        let segments = try c.decode([String].self, forKey: .relativePath)
        let budget = try c.decode(PDKCLIAccessBudgetWire.self, forKey: .budget)
        try PDKCLIInputCoding.id(key, resources: resources)
        try PDKCLIInputCoding.route(route, resources: resources)
        try PDKCLIInputCoding.id(root, resources: resources)
        for segment in segments { try PDKCLIInputCoding.work(resources, UInt64(segment.utf8.count) + 1) }
        value = .init(sourceKey: key, logicalRoute: route, rootID: try ArtifactRootID(rawValue: root),
            relativePath: try ArtifactRelativePath(segments: segments), budget: budget.value)
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion); try c.encode(value.sourceKey, forKey: .sourceKey)
        try c.encode(value.logicalRoute, forKey: .logicalRoute); try c.encode(value.rootID.rawValue, forKey: .rootID)
        try c.encode(value.relativePath.segments, forKey: .relativePath)
        try c.encode(PDKCLIAccessBudgetWire(value.budget), forKey: .budget)
    }
}
