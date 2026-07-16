import CircuiteFoundation
import Foundation
import PDKCore

public struct PDKValidationExecutionResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var artifacts: [ArtifactReference]
    public var provenance: ExecutionProvenance
    public var payload: PDKValidationPayload
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactReference] = [], provenance: ExecutionProvenance, payload: PDKValidationPayload) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.provenance = provenance; self.payload = payload }
}

public struct PDKCorpusValidationExecutionResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var artifacts: [ArtifactReference]
    public var provenance: ExecutionProvenance
    public var payload: PDKCorpusValidationPayload
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactReference] = [], provenance: ExecutionProvenance, payload: PDKCorpusValidationPayload) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.provenance = provenance; self.payload = payload }
}
