import Foundation
import CircuiteFoundation
import PDKCore

public struct PDKDiscoveryPayload: Sendable, Hashable, Codable {
    public var candidates: [PDKReference]
    public var inspectedManifestPaths: [String]

    public init(
        candidates: [PDKReference],
        inspectedManifestPaths: [String] = []
    ) {
        self.candidates = candidates
        self.inspectedManifestPaths = inspectedManifestPaths
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        candidates = try container.decode([PDKReference].self, forKey: .candidates)
        inspectedManifestPaths = try container.decode([String].self, forKey: .inspectedManifestPaths)
    }

    private enum CodingKeys: String, CodingKey {
        case candidates
        case inspectedManifestPaths
    }
}
