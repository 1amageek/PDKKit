import Foundation
import PDKCore
import PDKStandardViews
import CircuiteFoundation

public struct PDKKitOracleOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var oraclePath: String
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var payload: PDKOracleComparisonPayload

    public init(
        command: String,
        manifestPath: String,
        oraclePath: String,
        runID: String,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic],
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
