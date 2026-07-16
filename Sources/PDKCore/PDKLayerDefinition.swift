import Foundation

public struct PDKLayerDefinition: Sendable, Hashable, Codable {
    public var layerID: String
    public var name: String
    public var number: Int
    public var purpose: PDKLayerPurpose
    public var isRoutingLayer: Bool
    public var aliases: [String]
    public var minimumWidth: Double?
    public var minimumSpacing: Double?

    public init(
        layerID: String,
        name: String,
        number: Int,
        purpose: PDKLayerPurpose,
        isRoutingLayer: Bool = false,
        aliases: [String] = [],
        minimumWidth: Double? = nil,
        minimumSpacing: Double? = nil
    ) {
        self.layerID = layerID
        self.name = name
        self.number = number
        self.purpose = purpose
        self.isRoutingLayer = isRoutingLayer
        self.aliases = aliases
        self.minimumWidth = minimumWidth
        self.minimumSpacing = minimumSpacing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layerID = try container.decode(String.self, forKey: .layerID)
        name = try container.decode(String.self, forKey: .name)
        number = try container.decode(Int.self, forKey: .number)
        purpose = try container.decode(PDKLayerPurpose.self, forKey: .purpose)
        isRoutingLayer = try container.decodeIfPresent(Bool.self, forKey: .isRoutingLayer) ?? false
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        minimumWidth = try container.decodeIfPresent(Double.self, forKey: .minimumWidth)
        minimumSpacing = try container.decodeIfPresent(Double.self, forKey: .minimumSpacing)
    }

    private enum CodingKeys: String, CodingKey {
        case layerID
        case name
        case number
        case purpose
        case isRoutingLayer
        case aliases
        case minimumWidth
        case minimumSpacing
    }
}
