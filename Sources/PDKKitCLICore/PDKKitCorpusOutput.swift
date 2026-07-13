import Foundation
import PDKCore
import PDKValidation
import CircuiteFoundation

public struct PDKKitCorpusOutput: Sendable, Hashable, Codable {
    public var command: String
    public var suitePath: String
    public var rootPath: String
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var payload: PDKCorpusValidationPayload

    public init(
        command: String,
        suitePath: String,
        rootPath: String,
        runID: String,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic],
        payload: PDKCorpusValidationPayload
    ) {
        self.command = command
        self.suitePath = suitePath
        self.rootPath = rootPath
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.payload = payload
    }
}
