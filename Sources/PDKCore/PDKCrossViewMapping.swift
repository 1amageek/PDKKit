import Foundation

public struct PDKCrossViewMapping: Sendable, Hashable, Codable {
    public var mappingID: String
    public var view: PDKViewKind
    public var assetID: String
    public var logicalNames: [String]
    public var physicalNames: [String]
    public var layerIDs: [String]
    public var deviceIDs: [String]
    public var cornerIDs: [String]

    public init(
        mappingID: String,
        view: PDKViewKind,
        assetID: String,
        logicalNames: [String] = [],
        physicalNames: [String] = [],
        layerIDs: [String] = [],
        deviceIDs: [String] = [],
        cornerIDs: [String] = []
    ) {
        self.mappingID = mappingID
        self.view = view
        self.assetID = assetID
        self.logicalNames = logicalNames
        self.physicalNames = physicalNames
        self.layerIDs = layerIDs
        self.deviceIDs = deviceIDs
        self.cornerIDs = cornerIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mappingID = try container.decode(String.self, forKey: .mappingID)
        view = try container.decode(PDKViewKind.self, forKey: .view)
        assetID = try container.decode(String.self, forKey: .assetID)
        logicalNames = try container.decodeIfPresent([String].self, forKey: .logicalNames) ?? []
        physicalNames = try container.decodeIfPresent([String].self, forKey: .physicalNames) ?? []
        layerIDs = try container.decodeIfPresent([String].self, forKey: .layerIDs) ?? []
        deviceIDs = try container.decodeIfPresent([String].self, forKey: .deviceIDs) ?? []
        cornerIDs = try container.decodeIfPresent([String].self, forKey: .cornerIDs) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case mappingID
        case view
        case assetID
        case logicalNames
        case physicalNames
        case layerIDs
        case deviceIDs
        case cornerIDs
    }
}
