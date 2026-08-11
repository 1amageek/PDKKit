import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import PDKCore

public struct PDKStandardViewInspectionResult: Sendable, Hashable, Codable,
    ArtifactProducing, DiagnosticReporting, EvidenceProviding
{
    public var schemaVersion: Int
    public var runID: String
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public let artifacts: [ArtifactReference]
    public let provenance: ExecutionProvenance
    public var payload: PDKStandardViewInspectionPayload
    public let evidence: EvidenceManifest

    public init(
        schemaVersion: Int,
        runID: String,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic] = [],
        artifacts: [ArtifactReference] = [],
        provenance: ExecutionProvenance,
        payload: PDKStandardViewInspectionPayload
    ) throws {
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
