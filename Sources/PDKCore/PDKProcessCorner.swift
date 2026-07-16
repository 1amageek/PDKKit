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
        name = try container.decode(String.self, forKey: .name)
        nominal = try container.decode(Bool.self, forKey: .nominal)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case nominal
    }
}
