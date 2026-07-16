import CircuiteFoundation
import Foundation
import PDKCore

public struct PDKRuleDeckInspectionResult: Sendable, Hashable, Codable,
    ArtifactProducing, DiagnosticReporting, EvidenceProviding
{
    public var schemaVersion: Int
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var artifacts: [ArtifactReference]
    public var provenance: ExecutionProvenance
    public var payload: PDKRuleDeckInspectionPayload

    public var evidence: EvidenceManifest {
        EvidenceManifest(provenance: provenance, artifacts: artifacts)
    }

    public init(
        schemaVersion: Int,
        runID: String,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic] = [],
        artifacts: [ArtifactReference] = [],
        provenance: ExecutionProvenance,
        payload: PDKRuleDeckInspectionPayload
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.artifacts = artifacts
        self.provenance = provenance
        self.payload = payload
    }
}
