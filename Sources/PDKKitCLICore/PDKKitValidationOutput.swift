import Foundation
import PDKValidation
import XcircuitePackage

public struct PDKKitValidationOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var runID: String
    public var status: XcircuiteEngineExecutionStatus
    public var diagnostics: [XcircuiteEngineDiagnostic]
    public var payload: PDKValidationPayload

    public init(
        command: String,
        manifestPath: String,
        runID: String,
        status: XcircuiteEngineExecutionStatus,
        diagnostics: [XcircuiteEngineDiagnostic],
        payload: PDKValidationPayload
    ) {
        self.command = command
        self.manifestPath = manifestPath
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.payload = payload
    }
}
