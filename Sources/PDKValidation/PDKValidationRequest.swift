import Foundation
import XcircuitePackage
import PDKCore

public struct PDKValidationRequest: XcircuiteEngineRequest {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [XcircuiteFileReference]

    public var pdk: PDKReference
    public var requiredAssetRoles: [PDKAssetRole]
    public var validateCrossViews: Bool
    public var projectRootPath: String?

    public init(
        runID: String,
        inputs: [XcircuiteFileReference],
        pdk: PDKReference,
        requiredAssetRoles: [PDKAssetRole] = [],
        validateCrossViews: Bool = true,
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = inputs
        self.pdk = pdk
        self.requiredAssetRoles = requiredAssetRoles
        self.validateCrossViews = validateCrossViews
        self.projectRootPath = projectRootPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        runID = try container.decode(String.self, forKey: .runID)
        inputs = try container.decodeIfPresent([XcircuiteFileReference].self, forKey: .inputs) ?? []
        pdk = try container.decode(PDKReference.self, forKey: .pdk)
        requiredAssetRoles = try container.decodeIfPresent([PDKAssetRole].self, forKey: .requiredAssetRoles) ?? []
        validateCrossViews = try container.decodeIfPresent(Bool.self, forKey: .validateCrossViews) ?? true
        projectRootPath = try container.decodeIfPresent(String.self, forKey: .projectRootPath)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case inputs
        case pdk
        case requiredAssetRoles
        case validateCrossViews
        case projectRootPath
    }
}
