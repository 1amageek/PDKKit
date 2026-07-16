import Foundation
import PDKCore
import CircuiteFoundation

public struct PDKRuleDeckInspectionRequest: Sendable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [ArtifactLocator]
    public var pdk: PDKReference
    public var assetID: String
    public var requireNonEmpty: Bool
    public var projectRootPath: String?

    public init(
        runID: String,
        inputs: [ArtifactLocator],
        pdk: PDKReference,
        assetID: String,
        requireNonEmpty: Bool = true,
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = inputs
        self.pdk = pdk
        self.assetID = assetID
        self.requireNonEmpty = requireNonEmpty
        self.projectRootPath = projectRootPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported PDK rule-deck inspection request schema version: \(schemaVersion)"
            )
        }
        runID = try container.decode(String.self, forKey: .runID)
        inputs = try container.decode([ArtifactLocator].self, forKey: .inputs)
        pdk = try container.decode(PDKReference.self, forKey: .pdk)
        assetID = try container.decode(String.self, forKey: .assetID)
        requireNonEmpty = try container.decode(Bool.self, forKey: .requireNonEmpty)
        projectRootPath = try container.decodeIfPresent(String.self, forKey: .projectRootPath)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case inputs
        case pdk
        case assetID
        case requireNonEmpty
        case projectRootPath
    }
}
