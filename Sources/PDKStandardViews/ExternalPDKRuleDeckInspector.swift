import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
import PDKCore
import PDKSourceCapture

public struct ExternalPDKRuleDeckInspector: PDKRuleDeckInspecting {
    private let provider: any PDKExternalRuleDeckResultProviding
    private let decoder: PDKExternalInspectionResultDecoder
    private let clock: any PDKStandardViewExecutionClock
    private let assetResolver: any PDKAssetResolving
    private let sourceCapturer: any PDKLocalSourceCapturing
    private let captureBudget: ArtifactAccessBudget?

    public init(
        provider: any PDKExternalRuleDeckResultProviding,
        decoder: PDKExternalInspectionResultDecoder = PDKExternalInspectionResultDecoder(),
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock(),
        assetResolver: any PDKAssetResolving = LocalPDKAssetResolver(),
        sourceCapturer: any PDKLocalSourceCapturing = LocalPDKSourceCapturer(),
        captureBudget: ArtifactAccessBudget? = nil
    ) {
        self.provider = provider
        self.decoder = decoder
        self.clock = clock
        self.assetResolver = assetResolver
        self.sourceCapturer = sourceCapturer
        self.captureBudget = captureBudget
    }

    public func execute(
        _ request: PDKRuleDeckInspectionRequest
    ) async throws -> PDKRuleDeckInspectionResult {
        let startedAt = clock.now()
        var receivedArtifacts: [ArtifactReference] = []
        let data: Data
        do {
            data = try await provider.resultData(for: request)
        } catch is CancellationError {
            return try failureResult(
                request: request, startedAt: startedAt, status: .cancelled,
                finding: finding(
                    code: "pdk.external.rule-deck-provider-cancelled",
                    message: "The external inspection provider was cancelled.", severity: .warning,
                    actions: ["rerun_external_inspection"]
                )
            )
        } catch {
            return try failureResult(
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
            let result = try decoder.decodeRuleDeck(
                data,
                expectedSchemaVersion: PDKRuleDeckInspectionRequest.currentSchemaVersion,
                expectedRunID: request.runID
            )
            receivedArtifacts = result.artifacts
            try await validate(payload: result.payload, status: result.status, request: request)
            return result
        } catch let error as PDKSourceCaptureError {
            return try failureResult(
                request: request,
                startedAt: startedAt,
                status: error.classification == .cancellation ? .cancelled : .blocked,
                artifacts: receivedArtifacts,
                finding: finding(
                    code: "pdk.external.rule-deck-capture-failed",
                    message: "PDK manifest capture failed: \(error).",
                    severity: .blocker,
                    actions: ["restore_immutable_artifact", "inspect_capture_failure"]
                )
            )
        } catch let error as PDKExternalInspectionError {
            if receivedArtifacts.isEmpty {
                receivedArtifacts = artifacts(from: data)
            }
            let status: PDKExecutionStatus = isTrustBoundaryError(error) ? .blocked : .failed
            return try failureResult(
                request: request,
                startedAt: startedAt,
                status: status,
                artifacts: receivedArtifacts,
                finding: finding(
                    code: "pdk.external.rule-deck-contract-mismatch",
                    message: error.localizedDescription,
                    severity: status == .blocked ? .blocker : .error,
                    actions: ["repair_external_result", "rerun_external_rule_deck"]
                )
            )
        } catch {
            if receivedArtifacts.isEmpty {
                receivedArtifacts = artifacts(from: data)
            }
            return try failureResult(
                request: request,
                startedAt: startedAt,
                status: .failed,
                artifacts: receivedArtifacts,
                finding: finding(
                    code: "pdk.external.rule-deck-result-invalid",
                    message: "External rule-deck result could not be validated: " + error.localizedDescription,
                    severity: .error,
                    actions: ["repair_external_result", "rerun_external_rule_deck"]
                )
            )
        }
    }

    private func validate(
        payload: PDKRuleDeckInspectionPayload,
        status: PDKExecutionStatus,
        request: PDKRuleDeckInspectionRequest
    ) async throws {
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
            let expectedIdentity = try await expectedRuleDeckIdentity(for: request)
            let expectedArtifact = expectedIdentity.artifact
            let expectedReference = expectedIdentity.reference
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
            guard sourceArtifact == expectedArtifact else {
                throw PDKExternalInspectionError.canonicalArtifactMismatch(
                    expected: Self.artifactDescription(expectedArtifact),
                    actual: Self.artifactDescription(sourceArtifact)
                )
            }
        }
    }

    private func expectedRuleDeckIdentity(
        for request: PDKRuleDeckInspectionRequest
    ) async throws -> (reference: ArtifactLocator, artifact: ArtifactReference) {
        let manifestURL: URL
        do {
            manifestURL = try PDKArtifactURLResolver().resolve(
                request.pdk.manifestLocator,
                baseDirectoryPath: request.projectRootPath
            )
        } catch {
            throw PDKExternalInspectionError.inputReferenceUnavailable(error.localizedDescription)
        }
        let manifestData: Data
        do {
            let budget = try captureBudget ?? PDKSourceCapturePolicy.defaultBudget
            let captured = try await sourceCapturer.capture(
                reference: request.pdk.manifest,
                at: request.pdk.manifestLocator,
                relativeTo: request.pdk.manifestLocator.location.storage == .workspaceRelative
                    ? URL(filePath: request.projectRootPath ?? FileManager.default.currentDirectoryPath) : nil,
                budget: budget
            )
            manifestData = try captured.data(maximumByteCount: budget.maximumTotalByteCount)
        } catch let error as PDKSourceCaptureError {
            throw error
        } catch {
            throw PDKExternalInspectionError.inputReferenceUnavailable(
                "PDK manifest capture budget failed: \(error)"
            )
        }
        do {
            let manifest = try PDKManifestCodec.decode(data: manifestData)
            guard let asset = manifest.assets.first(where: { $0.assetID == request.assetID }) else {
                throw PDKExternalInspectionError.inputReferenceUnavailable(
                    "PDK manifest does not declare asset \(request.assetID)"
                )
            }
            let resolved = try assetResolver.resolve(asset, relativeTo: manifestURL)
            let identityFindings = asset.identityFindings(for: resolved.reference)
            guard identityFindings.isEmpty else {
                throw PDKExternalInspectionError.inputReferenceUnavailable(
                    identityFindings.map(\.code).joined(separator: ", ")
                )
            }
            if let expected = request.expectedSourceArtifact, expected != resolved.reference {
                throw PDKExternalInspectionError.canonicalArtifactMismatch(
                    expected: Self.artifactDescription(expected), actual: Self.artifactDescription(resolved.reference)
                )
            }
            return (
                reference: resolved.locator,
                artifact: resolved.reference
            )
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

    private static func referenceDescription(_ reference: ArtifactLocator) -> String {
        [
            reference.path,
            reference.kind.rawValue,
            reference.format.rawValue,
        ].joined(separator: "|")
    }

    private static func artifactDescription(_ reference: ArtifactReference) -> String {
        [
            reference.id.description,
            reference.kind.rawValue,
            reference.format.rawValue,
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

    private func failureResult(
        request: PDKRuleDeckInspectionRequest,
        startedAt: Date,
        status: PDKExecutionStatus,
        artifacts: [ArtifactReference] = [],
        finding: PDKValidationFinding
    ) throws -> PDKRuleDeckInspectionResult {
        try PDKRuleDeckInspectionResult(
            schemaVersion: PDKRuleDeckInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: [PDKStandardViewDiagnosticMapper.map(finding)],
            artifacts: artifacts,
            provenance: try PDKExecutionProvenance.make(
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
                    "The external backend result was rejected at the typed result boundary.",
                    "External tool qualification and process scope are evaluated outside this adapter."
                ]
            )
        )
    }

    private func artifacts(from data: Data) -> [ArtifactReference] {
        do {
            return try JSONDecoder().decode(ArtifactContainer.self, from: data).artifacts
        } catch {
            return []
        }
    }

    private struct ArtifactContainer: Decodable {
        var artifacts: [ArtifactReference] = []
    }
}
