import CircuiteFoundation
import Foundation
import PDKCore

public struct PDKStandardViewInspectionResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int; public var runID: String; public var status: PDKExecutionStatus; public var diagnostics: [DesignDiagnostic]; public var artifacts: [ArtifactLocator]; public var metadata: PDKExecutionMetadata; public var payload: PDKStandardViewInspectionPayload
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactLocator] = [], metadata: PDKExecutionMetadata, payload: PDKStandardViewInspectionPayload) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.metadata = metadata; self.payload = payload }
}

public struct PDKRuleDeckInspectionResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int; public var runID: String; public var status: PDKExecutionStatus; public var diagnostics: [DesignDiagnostic]; public var artifacts: [ArtifactLocator]; public var metadata: PDKExecutionMetadata; public var payload: PDKRuleDeckInspectionPayload
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactLocator] = [], metadata: PDKExecutionMetadata, payload: PDKRuleDeckInspectionPayload) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.metadata = metadata; self.payload = payload }
}

public struct PDKManifestViewInspectionResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int; public var runID: String; public var status: PDKExecutionStatus; public var diagnostics: [DesignDiagnostic]; public var artifacts: [ArtifactLocator]; public var metadata: PDKExecutionMetadata; public var payload: PDKManifestViewInspectionPayload
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactLocator] = [], metadata: PDKExecutionMetadata, payload: PDKManifestViewInspectionPayload) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.metadata = metadata; self.payload = payload }
}

public struct PDKOracleComparisonResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int; public var runID: String; public var status: PDKExecutionStatus; public var diagnostics: [DesignDiagnostic]; public var artifacts: [ArtifactLocator]; public var metadata: PDKExecutionMetadata; public var payload: PDKOracleComparisonPayload
    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactLocator] = [], metadata: PDKExecutionMetadata, payload: PDKOracleComparisonPayload) { self.schemaVersion = schemaVersion; self.runID = runID; self.status = status; self.diagnostics = diagnostics; self.artifacts = artifacts; self.metadata = metadata; self.payload = payload }
}
