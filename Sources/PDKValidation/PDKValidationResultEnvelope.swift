import CircuiteFoundation
import Foundation
import PDKCore

public struct PDKValidationExecutionResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var artifacts: [ArtifactLocator]
    public var metadata: PDKExecutionMetadata
    public var payload: PDKValidationPayload
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactLocator] = [], metadata: PDKExecutionMetadata, payload: PDKValidationPayload) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.metadata = metadata; self.payload = payload }
}

public struct PDKCorpusValidationExecutionResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var artifacts: [ArtifactLocator]
    public var metadata: PDKExecutionMetadata
    public var payload: PDKCorpusValidationPayload
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactLocator] = [], metadata: PDKExecutionMetadata, payload: PDKCorpusValidationPayload) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.metadata = metadata; self.payload = payload }
}

public struct PDKQualificationExecutionResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var artifacts: [ArtifactLocator]
    public var metadata: PDKExecutionMetadata
    public var payload: PDKQualificationAssessment
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactLocator] = [], metadata: PDKExecutionMetadata, payload: PDKQualificationAssessment) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.metadata = metadata; self.payload = payload }
}
