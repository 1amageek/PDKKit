import Foundation
import PDKCore
import PDKValidation
import CircuiteFoundation

public struct PDKKitQualificationOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var corpusPath: String
    public var oraclePath: String
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var assessment: PDKQualificationAssessment

    public init(
        command: String,
        manifestPath: String,
        corpusPath: String,
        oraclePath: String,
        runID: String,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic],
        assessment: PDKQualificationAssessment
    ) {
        self.command = command
        self.manifestPath = manifestPath
        self.corpusPath = corpusPath
        self.oraclePath = oraclePath
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.assessment = assessment
    }
}
