import Foundation
import PDKCore
import XcircuitePackage

public struct PDKOracleRequest: XcircuiteEngineRequest {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [XcircuiteFileReference]
    public var pdk: PDKReference
    public var oracle: XcircuiteFileReference
    public var projectRootPath: String?

    public init(
        runID: String,
        pdk: PDKReference,
        oracle: XcircuiteFileReference,
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = [pdk.manifest, oracle]
        self.pdk = pdk
        self.oracle = oracle
        self.projectRootPath = projectRootPath
    }
}
