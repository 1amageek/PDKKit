import Foundation
import CircuiteFoundation
import PDKCore

public struct PDKValidationRequest: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [ArtifactLocator]

    public var pdk: PDKReference
    public var requiredAssetRoles: [PDKAssetRole]
    public var validateCrossViews: Bool
    public var validateStandardViews: Bool
    public var validateRuleDecks: Bool
    public var projectRootPath: String?

    public init(
        runID: String,
        inputs: [ArtifactLocator],
        pdk: PDKReference,
        requiredAssetRoles: [PDKAssetRole] = [],
        validateCrossViews: Bool = true,
        validateStandardViews: Bool = true,
        validateRuleDecks: Bool = true,
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = inputs
        self.pdk = pdk
        self.requiredAssetRoles = requiredAssetRoles
        self.validateCrossViews = validateCrossViews
        self.validateStandardViews = validateStandardViews
        self.validateRuleDecks = validateRuleDecks
        self.projectRootPath = projectRootPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported PDK validation request schema version: \(schemaVersion)"
            )
        }
        runID = try container.decode(String.self, forKey: .runID)
        inputs = try container.decode([ArtifactLocator].self, forKey: .inputs)
        pdk = try container.decode(PDKReference.self, forKey: .pdk)
        requiredAssetRoles = try container.decode([PDKAssetRole].self, forKey: .requiredAssetRoles)
        validateCrossViews = try container.decode(Bool.self, forKey: .validateCrossViews)
        validateStandardViews = try container.decode(Bool.self, forKey: .validateStandardViews)
        validateRuleDecks = try container.decode(Bool.self, forKey: .validateRuleDecks)
        projectRootPath = try container.decodeIfPresent(String.self, forKey: .projectRootPath)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case inputs
        case pdk
        case requiredAssetRoles
        case validateCrossViews
        case validateStandardViews
        case validateRuleDecks
        case projectRootPath
    }
}
