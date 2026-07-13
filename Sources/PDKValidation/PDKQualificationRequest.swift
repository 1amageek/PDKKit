import Foundation
import PDKCore
import CircuiteFoundation

public struct PDKQualificationRequest: Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [ArtifactLocator]
    public var pdk: PDKReference
    public var corpusReport: ArtifactReference
    public var oracleReport: ArtifactReference
    public var projectRootPath: String?

    public init(
        runID: String,
        pdk: PDKReference,
        corpusReport: ArtifactReference,
        oracleReport: ArtifactReference,
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = [pdk.manifest.locator, corpusReport.locator, oracleReport.locator]
        self.pdk = pdk
        self.corpusReport = corpusReport
        self.oracleReport = oracleReport
        self.projectRootPath = projectRootPath
    }
}
