import Foundation
import PDKCore
import PDKStandardViews
import CircuiteFoundation

public struct PDKKitRuleDeckOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var assetID: String
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var payload: PDKRuleDeckInspectionPayload

    public init(
        command: String,
        manifestPath: String,
        assetID: String,
        runID: String,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic],
        payload: PDKRuleDeckInspectionPayload
    ) {
        self.command = command
        self.manifestPath = manifestPath
        self.assetID = assetID
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.payload = payload
    }
}
