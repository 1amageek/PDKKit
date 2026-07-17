import CircuiteFoundation
import Foundation
import PDKCore

public struct PDKStandardViewInspectionResult: Sendable, Hashable, Codable,
    ArtifactProducing, DiagnosticReporting, EvidenceProviding
{
    public var schemaVersion: Int
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var artifacts: [ArtifactReference] {
        didSet { evidence = EvidenceManifest(id: evidence.id, provenance: provenance, artifacts: artifacts) }
    }
    public var provenance: ExecutionProvenance {
        didSet { evidence = EvidenceManifest(id: evidence.id, provenance: provenance, artifacts: artifacts) }
    }
    public var payload: PDKStandardViewInspectionPayload
    public private(set) var evidence: EvidenceManifest

    public init(
        schemaVersion: Int,
        runID: String,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic] = [],
        artifacts: [ArtifactReference] = [],
        provenance: ExecutionProvenance,
        payload: PDKStandardViewInspectionPayload
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.artifacts = artifacts
        self.provenance = provenance
        self.payload = payload
        self.evidence = EvidenceManifest(provenance: provenance, artifacts: artifacts)
    }
}
