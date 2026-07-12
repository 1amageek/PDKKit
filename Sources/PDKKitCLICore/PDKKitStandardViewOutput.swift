import Foundation
import PDKStandardViews
import XcircuitePackage

public struct PDKKitStandardViewOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var assetID: String
    public var format: PDKStandardViewFormat
    public var runID: String
    public var status: XcircuiteEngineExecutionStatus
    public var diagnostics: [XcircuiteEngineDiagnostic]
    public var payload: PDKManifestViewInspectionPayload

    public init(
        command: String,
        manifestPath: String,
        assetID: String,
        format: PDKStandardViewFormat,
        runID: String,
        status: XcircuiteEngineExecutionStatus,
        diagnostics: [XcircuiteEngineDiagnostic],
        payload: PDKManifestViewInspectionPayload
    ) {
        self.command = command
        self.manifestPath = manifestPath
        self.assetID = assetID
        self.format = format
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.payload = payload
    }
}
