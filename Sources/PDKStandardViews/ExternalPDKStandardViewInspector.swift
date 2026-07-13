import Foundation
import CircuiteFoundation
import PDKCore
import CircuiteFoundation

public struct ExternalPDKStandardViewInspector: PDKStandardViewInspecting {
    private let provider: any PDKExternalStandardViewResultProviding
    private let decoder: PDKExternalInspectionEnvelopeDecoder
    private let clock: any PDKStandardViewExecutionClock

    public init(
        provider: any PDKExternalStandardViewResultProviding,
        decoder: PDKExternalInspectionEnvelopeDecoder = PDKExternalInspectionEnvelopeDecoder(),
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock()
    ) {
        self.provider = provider
        self.decoder = decoder
        self.clock = clock
    }

    public func execute(
        _ request: PDKStandardViewInspectionRequest
    ) async throws -> PDKStandardViewInspectionResult {
        let startedAt = clock.now()
        var receivedArtifacts: [ArtifactLocator] = []
        let data: Data
        do {
            data = try await provider.resultData(for: request)
        } catch {
            return failureEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                finding: finding(
                    code: "pdk.external.standard-view-provider-failed",
                    message: "External standard-view provider failed: " + error.localizedDescription,
                    severity: .error,
                    actions: ["inspect_external_tool_log", "rerun_external_standard_view"]
                )
            )
        }

        do {
            let envelope = try decoder.decodeStandardView(
                data,
                expectedSchemaVersion: PDKStandardViewInspectionRequest.currentSchemaVersion,
                expectedRunID: request.runID
            )
            receivedArtifacts = envelope.artifacts
            try validate(payload: envelope.payload, status: envelope.status, request: request)
            return envelope
        } catch let error as PDKExternalInspectionError {
            if receivedArtifacts.isEmpty {
                receivedArtifacts = artifacts(from: data)
            }
            let status: PDKExecutionStatus = isTrustBoundaryError(error) ? .blocked : .failed
            return failureEnvelope(
                request: request,
                startedAt: startedAt,
                status: status,
                artifacts: receivedArtifacts,
                finding: finding(
                    code: "pdk.external.standard-view-contract-mismatch",
                    message: error.localizedDescription,
                    severity: status == .blocked ? .blocker : .error,
                    actions: ["repair_external_result_envelope", "rerun_external_standard_view"]
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
                    code: "pdk.external.standard-view-result-invalid",
                    message: "External standard-view result could not be validated: " + error.localizedDescription,
                    severity: .error,
                    actions: ["repair_external_result_envelope", "rerun_external_standard_view"]
                )
            )
        }
    }

    private func validate(
        payload: PDKStandardViewInspectionPayload,
        status: PDKExecutionStatus,
        request: PDKStandardViewInspectionRequest
    ) throws {
        guard payload.assetID == request.assetID else {
            throw PDKExternalInspectionError.assetIDMismatch(
                expected: request.assetID,
                actual: payload.assetID
            )
        }
        if let inspection = payload.inspection, inspection.format != request.format {
            throw PDKExternalInspectionError.standardViewFormatMismatch(
                expected: request.format,
                actual: inspection.format
            )
        }
        if let inspection = payload.inspection {
            guard request.inputs.contains(where: { $0 == inspection.source }) else {
                throw PDKExternalInspectionError.inputReferenceMismatch(
                    expected: request.inputs.map(Self.referenceDescription).sorted().joined(separator: ", "),
                    actual: Self.referenceDescription(inspection.source)
                )
            }
            guard let sourceArtifact = inspection.sourceArtifact else {
                throw PDKExternalInspectionError.canonicalArtifactMismatch(
                    expected: "digest-bearing CircuiteFoundation ArtifactReference",
                    actual: "<missing>"
                )
            }
            let expectedArtifact: ArtifactReference
            do {
                let sourceURL = try PDKArtifactURLResolver().resolve(
                    inspection.source,
                    baseDirectoryPath: request.projectRootPath
                )
                expectedArtifact = try PDKFoundationArtifactBridge.artifactReference(
                    for: inspection.source,
                    resolvedURL: sourceURL
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
        if status == .completed {
            guard payload.isValid, payload.inspection != nil else {
                throw PDKExternalInspectionError.completedPayloadInvalid(
                    "completed standard-view results must contain a valid canonical inspection"
                )
            }
        }
    }

    private func isTrustBoundaryError(_ error: PDKExternalInspectionError) -> Bool {
        switch error {
        case .schemaVersionMismatch, .runIDMismatch, .assetIDMismatch, .standardViewFormatMismatch, .pdkDigestMismatch,
             .inputReferenceMismatch, .canonicalArtifactMismatch, .inputReferenceUnavailable:
            true
        case .invalidJSON, .completedPayloadInvalid:
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
            entity: "external-standard-view",
            suggestedActions: actions
        )
    }

    private func failureEnvelope(
        request: PDKStandardViewInspectionRequest,
        startedAt: Date,
        status: PDKExecutionStatus,
        artifacts: [ArtifactLocator] = [],
        finding: PDKValidationFinding
    ) -> PDKStandardViewInspectionResult {
        PDKStandardViewInspectionResult(
            schemaVersion: PDKStandardViewInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: [PDKStandardViewDiagnosticMapper.map(finding)],
            artifacts: artifacts,
            metadata: PDKExecutionMetadata(
                engineID: "PDKStandardViewInspection",
                implementationID: "ExternalPDKStandardViewInspector",
                implementationVersion: "1",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: PDKStandardViewInspectionPayload(
                isValid: false,
                assetID: request.assetID,
                findings: [finding],
                parserID: "external",
                parserVersion: "unknown",
                limitations: [
                    "The external backend result was rejected at the typed result boundary.",
                    "External tool qualification and process scope are evaluated outside this adapter."
                ]
            )
        )
    }

    private func artifacts(from data: Data) -> [ArtifactLocator] {
        do {
            return try JSONDecoder().decode(ArtifactContainer.self, from: data).artifacts
        } catch {
            return []
        }
    }

    private struct ArtifactContainer: Decodable {
        var artifacts: [ArtifactLocator] = []
    }
}
