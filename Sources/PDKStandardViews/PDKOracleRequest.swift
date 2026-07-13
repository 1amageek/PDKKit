import Foundation
import PDKCore
import CircuiteFoundation

public struct PDKOracleRequest: Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [ArtifactLocator]
    public var pdk: PDKReference
    public var oracle: ArtifactReference
    public var projectRootPath: String?

    public init(
        runID: String,
        pdk: PDKReference,
        oracle: ArtifactReference,
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = [pdk.manifest.locator, oracle.locator]
        self.pdk = pdk
        self.oracle = oracle
        self.projectRootPath = projectRootPath
    }
}
