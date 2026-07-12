import Foundation
import PDKStandardViews
import XcircuitePackage

public struct PDKKitOracleOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var oraclePath: String
    public var runID: String
    public var status: XcircuiteEngineExecutionStatus
    public var diagnostics: [XcircuiteEngineDiagnostic]
    public var payload: PDKOracleComparisonPayload

    public init(
        command: String,
        manifestPath: String,
        oraclePath: String,
        runID: String,
        status: XcircuiteEngineExecutionStatus,
        diagnostics: [XcircuiteEngineDiagnostic],
        payload: PDKOracleComparisonPayload
    ) {
        self.command = command
        self.manifestPath = manifestPath
        self.oraclePath = oraclePath
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.payload = payload
    }
}
