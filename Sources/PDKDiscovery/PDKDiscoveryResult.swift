import CircuiteFoundation
import CircuiteFoundationCrypto
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
    public let evidence: EvidenceManifest

    public init(schemaVersion: Int, runID: String, status: PDKExecutionStatus, diagnostics: [DesignDiagnostic] = [], artifacts: [ArtifactReference] = [], provenance: ExecutionProvenance, payload: PDKDiscoveryPayload) throws {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.artifacts = artifacts
        self.provenance = provenance
        self.payload = payload
        self.evidence = try EvidenceManifest.contentAddressed(
            provenance: provenance,
            artifacts: artifacts,
            digester: SHA256ContentDigester()
        )
    }
}
