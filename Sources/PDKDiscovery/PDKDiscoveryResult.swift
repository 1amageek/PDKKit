import CircuiteFoundation
import Foundation
import PDKCore

public struct PDKDiscoveryResult: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let runID: String
    public let status: PDKExecutionStatus
    public let diagnostics: [DesignDiagnostic]
    public let artifacts: [ArtifactLocator]
    public let metadata: PDKExecutionMetadata
    public let payload: PDKDiscoveryPayload

    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactLocator] = [], metadata: PDKExecutionMetadata, payload: PDKDiscoveryPayload) {
        self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.metadata = metadata; self.payload = payload
    }
}
