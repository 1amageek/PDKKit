import Foundation
import PDKCore
import PDKValidation
import CircuiteFoundation

public struct PDKKitValidationOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var payload: PDKValidationPayload

    public init(
        command: String,
        manifestPath: String,
        runID: String,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic],
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
