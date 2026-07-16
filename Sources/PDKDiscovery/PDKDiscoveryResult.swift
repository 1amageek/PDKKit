import CircuiteFoundation
import Foundation
import PDKCore

public struct PDKDiscoveryResult: Sendable, Hashable, Codable,
    ArtifactProducing, DiagnosticReporting, EvidenceProviding
{
    public let schemaVersion: Int
    public let runID: String
    public let status: PDKExecutionStatus
    public let diagnostics: [DesignDiagnostic]
    public let artifacts: [ArtifactReference]
    public let provenance: ExecutionProvenance
    public let payload: PDKDiscoveryPayload

    public var evidence: EvidenceManifest {
        EvidenceManifest(provenance: provenance, artifacts: artifacts)
    }

    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactReference] = [], provenance: ExecutionProvenance, payload: PDKDiscoveryPayload) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.artifacts = artifacts
        self.provenance = provenance
        self.payload = payload
    }
}
