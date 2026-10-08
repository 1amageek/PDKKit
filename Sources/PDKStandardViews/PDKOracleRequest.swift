import Foundation
import PDKCore
import CircuiteFoundation
import CircuiteFoundationFoundation

public struct PDKOracleRequest: Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [ArtifactLocator]
    public var pdk: PDKReference
    public var oracle: ArtifactReference
    public var oracleLocator: ArtifactLocator
    public var projectRootPath: String?

    public init(
        runID: String,
        pdk: PDKReference,
        oracle: ArtifactReference,
        oracleLocator: ArtifactLocator,
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = [pdk.manifestLocator, oracleLocator]
        self.pdk = pdk
        self.oracle = oracle
        self.oracleLocator = oracleLocator
        self.projectRootPath = projectRootPath
    }
}
