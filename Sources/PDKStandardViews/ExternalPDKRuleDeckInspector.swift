import Foundation
import CircuiteFoundation
import PDKCore
import XcircuitePackage

public struct ExternalPDKRuleDeckInspector: PDKRuleDeckInspecting {
    private let provider: any PDKExternalRuleDeckResultProviding
    private let decoder: PDKExternalInspectionEnvelopeDecoder
    private let clock: any PDKStandardViewExecutionClock
    private let assetResolver: any PDKAssetResolving

    public init(
        provider: any PDKExternalRuleDeckResultProviding,
        decoder: PDKExternalInspectionEnvelopeDecoder = PDKExternalInspectionEnvelopeDecoder(),
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock(),
        assetResolver: any PDKAssetResolving = LocalPDKAssetResolver()
    ) {
        self.provider = provider
        self.decoder = decoder
        self.clock = clock
        self.assetResolver = assetResolver
    }

    public func execute(
        _ request: PDKRuleDeckInspectionRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKRuleDeckInspectionPayload> {
        let startedAt = clock.now()
        var receivedArtifacts: [XcircuiteFileReference] = []
        let data: Data
        do {
            data = try await provider.resultData(for: request)
        } catch {
            return failureEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                finding: finding(
                    code: "pdk.external.rule-deck-provider-failed",
                    message: "External rule-deck provider failed: " + error.localizedDescription,
                    severity: .error,
                    actions: ["inspect_external_tool_log", "rerun_external_rule_deck"]
                )
            )
        }

        do {
            let envelope = try decoder.decode(
                data,
                payload: PDKRuleDeckInspectionPayload.self,
                expectedSchemaVersion: PDKRuleDeckInspectionRequest.currentSchemaVersion,
                expectedRunID: request.runID
            )
            receivedArtifacts = envelope.artifacts
            try validate(payload: envelope.payload, status: envelope.status, request: request)
            return envelope
        } catch let error as PDKExternalInspectionError {
            if receivedArtifacts.isEmpty {
                receivedArtifacts = artifacts(from: data)
            }
            let status: XcircuiteEngineExecutionStatus = isTrustBoundaryError(error) ? .blocked : .failed
            return failureEnvelope(
                request: request,
                startedAt: startedAt,
                status: status,
                artifacts: receivedArtifacts,
                finding: finding(
                    code: "pdk.external.rule-deck-contract-mismatch",
                    message: error.localizedDescription,
                    severity: status == .blocked ? .blocker : .error,
                    actions: ["repair_external_result_envelope", "rerun_external_rule_deck"]
                )
            )
        } catch {
            if receivedArtifacts.isEmpty {
                receivedArtifacts = artifacts(from: data)
            }
            return failureEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                artifacts: receivedArtifacts,
                finding: finding(
                    code: "pdk.external.rule-deck-result-invalid",
                    message: "External rule-deck result could not be validated: " + error.localizedDescription,
                    severity: .error,
                    actions: ["repair_external_result_envelope", "rerun_external_rule_deck"]
                )
            )
        }
    }

    private func validate(
        payload: PDKRuleDeckInspectionPayload,
        status: XcircuiteEngineExecutionStatus,
        request: PDKRuleDeckInspectionRequest
    ) throws {
        guard payload.assetID == request.assetID else {
            throw PDKExternalInspectionError.assetIDMismatch(
                expected: request.assetID,
                actual: payload.assetID
            )
        }
        guard payload.pdkDigest == request.pdk.digest else {
            throw PDKExternalInspectionError.pdkDigestMismatch(
                expected: request.pdk.digest,
                actual: payload.pdkDigest
            )
        }
        if status == .completed, !payload.isValid {
            throw PDKExternalInspectionError.completedPayloadInvalid(
                "completed rule-deck results must be valid"
            )
        }
        if status == .completed {
            let expectedReference = try expectedRuleDeckReference(for: request)
            guard let actualReference = payload.reference else {
                throw PDKExternalInspectionError.inputReferenceMismatch(
                    expected: Self.referenceDescription(expectedReference),
                    actual: "<missing>"
                )
            }
            guard actualReference == expectedReference else {
                throw PDKExternalInspectionError.inputReferenceMismatch(
                    expected: Self.referenceDescription(expectedReference),
                    actual: Self.referenceDescription(actualReference)
                )
            }
            guard let sourceArtifact = payload.sourceArtifact else {
                throw PDKExternalInspectionError.canonicalArtifactMismatch(
                    expected: "digest-bearing CircuiteFoundation ArtifactReference",
                    actual: "<missing>"
                )
            }
            let expectedArtifact: ArtifactReference
            do {
                expectedArtifact = try PDKFoundationArtifactBridge.artifactReference(
                    for: expectedReference
                )
            } catch {
                throw PDKExternalInspectionError.inputReferenceUnavailable(error.localizedDescription)
            }
            guard sourceArtifact.id == expectedArtifact.id,
                  sourceArtifact.digest == expectedArtifact.digest,
                  sourceArtifact.byteCount == expectedArtifact.byteCount,
                  sourceArtifact.locator.kind == expectedArtifact.locator.kind,
                  sourceArtifact.locator.format == expectedArtifact.locator.format else {
                throw PDKExternalInspectionError.canonicalArtifactMismatch(
                    expected: Self.artifactDescription(expectedArtifact),
                    actual: Self.artifactDescription(sourceArtifact)
                )
            }
        }
    }

    private func expectedRuleDeckReference(
        for request: PDKRuleDeckInspectionRequest
    ) throws -> XcircuiteFileReference {
        let manifestURL: URL
        do {
            manifestURL = try PDKArtifactURLResolver().resolve(
                request.pdk.manifest,
                baseDirectoryPath: request.projectRootPath
            )
        } catch {
            throw PDKExternalInspectionError.inputReferenceUnavailable(error.localizedDescription)
        }
        let manifestData: Data
        do {
            let manifestArtifact = try PDKFoundationArtifactBridge.artifactReference(
                for: request.pdk.manifest,
                resolvedURL: manifestURL
            )
            let integrity = LocalArtifactVerifier().verify(manifestArtifact)
            guard integrity.isVerified else {
                throw PDKExternalInspectionError.inputReferenceUnavailable(
                    "PDK manifest integrity failed: " + integrity.issues.map { $0.code.rawValue }.joined(separator: ", ")
                )
            }
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            throw PDKExternalInspectionError.inputReferenceUnavailable(
                "PDK manifest could not be read: \(error.localizedDescription)"
            )
        }
        do {
            let manifest = try PDKManifestCodec.decode(data: manifestData).manifest
            guard let asset = manifest.assets.first(where: { $0.assetID == request.assetID }) else {
                throw PDKExternalInspectionError.inputReferenceUnavailable(
                    "PDK manifest does not declare asset \(request.assetID)"
                )
            }
            return try assetResolver.resolve(asset, relativeTo: manifestURL).reference
        } catch let error as PDKExternalInspectionError {
            throw error
        } catch {
            throw PDKExternalInspectionError.inputReferenceUnavailable(error.localizedDescription)
        }
    }

    private func isTrustBoundaryError(_ error: PDKExternalInspectionError) -> Bool {
        switch error {
        case .schemaVersionMismatch, .runIDMismatch, .assetIDMismatch, .pdkDigestMismatch,
             .inputReferenceMismatch, .canonicalArtifactMismatch, .inputReferenceUnavailable:
            true
        case .invalidJSON, .standardViewFormatMismatch, .completedPayloadInvalid:
            false
        }
    }

    private static func referenceDescription(_ reference: XcircuiteFileReference) -> String {
        [
            reference.artifactID ?? "<anonymous>",
            reference.path,
            reference.kind.rawValue,
            reference.format.rawValue,
            reference.sha256 ?? "<missing-sha256>",
            reference.byteCount.map(String.init) ?? "<missing-byte-count>",
        ].joined(separator: "|")
    }

    private static func artifactDescription(_ reference: ArtifactReference) -> String {
        [
            reference.id.rawValue,
            reference.locator.kind.rawValue,
            reference.locator.format.rawValue,
            reference.digest.hexadecimalValue,
            String(reference.byteCount),
        ].joined(separator: "|")
    }

    private func finding(
        code: String,
        message: String,
        severity: PDKFindingSeverity,
        actions: [String]
    ) -> PDKValidationFinding {
        PDKValidationFinding(
            severity: severity,
            code: code,
            message: message,
            entity: "external-rule-deck",
            suggestedActions: actions
        )
    }

    private func failureEnvelope(
        request: PDKRuleDeckInspectionRequest,
        startedAt: Date,
        status: XcircuiteEngineExecutionStatus,
        artifacts: [XcircuiteFileReference] = [],
        finding: PDKValidationFinding
    ) -> XcircuiteEngineResultEnvelope<PDKRuleDeckInspectionPayload> {
        XcircuiteEngineResultEnvelope(
            schemaVersion: PDKRuleDeckInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: [PDKStandardViewDiagnosticMapper.map(finding)],
            artifacts: artifacts,
            metadata: XcircuiteEngineExecutionMetadata(
                engineID: "PDKRuleDeckInspection",
                implementationID: "ExternalPDKRuleDeckInspector",
                implementationVersion: "1",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: PDKRuleDeckInspectionPayload(
                isValid: false,
                assetID: request.assetID,
                pdkDigest: request.pdk.digest,
                findings: [finding],
                limitations: [
                    "The external backend result was rejected at the shared envelope boundary.",
                    "External tool qualification and process scope are evaluated outside this adapter."
                ]
            )
        )
    }

    private func artifacts(from data: Data) -> [XcircuiteFileReference] {
        do {
            return try JSONDecoder().decode(ArtifactContainer.self, from: data).artifacts
        } catch {
            return []
        }
    }

    private struct ArtifactContainer: Decodable {
        var artifacts: [XcircuiteFileReference] = []
    }
}
