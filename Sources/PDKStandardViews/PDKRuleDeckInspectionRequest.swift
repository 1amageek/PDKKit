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
}
