import Foundation
import PDKCore
import XcircuitePackage

public struct PDKQualificationRequest: XcircuiteEngineRequest {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [XcircuiteFileReference]
    public var pdk: PDKReference
    public var corpusReport: XcircuiteFileReference
    public var oracleReport: XcircuiteFileReference
    public var projectRootPath: String?

    public init(
        runID: String,
        pdk: PDKReference,
        corpusReport: XcircuiteFileReference,
        oracleReport: XcircuiteFileReference,
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = [pdk.manifest, corpusReport, oracleReport]
        self.pdk = pdk
        self.corpusReport = corpusReport
        self.oracleReport = oracleReport
        self.projectRootPath = projectRootPath
    }
}
