import Foundation

public struct PDKProcessCorner: Sendable, Hashable, Codable {
    public var name: String
    public var nominal: Bool

    public init(name: String, nominal: Bool = false) {
        self.name = name
        self.nominal = nominal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nominal = try container.decodeIfPresent(Bool.self, forKey: .nominal) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case nominal
    }
}
