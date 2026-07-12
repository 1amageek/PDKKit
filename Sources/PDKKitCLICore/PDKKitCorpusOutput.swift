import Foundation
import PDKValidation
import XcircuitePackage

public struct PDKKitCorpusOutput: Sendable, Hashable, Codable {
    public var command: String
    public var suitePath: String
    public var rootPath: String
    public var runID: String
    public var status: XcircuiteEngineExecutionStatus
    public var diagnostics: [XcircuiteEngineDiagnostic]
    public var payload: PDKCorpusValidationPayload

    public init(
        command: String,
        suitePath: String,
        rootPath: String,
        runID: String,
        status: XcircuiteEngineExecutionStatus,
        diagnostics: [XcircuiteEngineDiagnostic],
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
