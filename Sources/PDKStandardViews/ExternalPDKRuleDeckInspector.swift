import Foundation
import PDKCore
import XcircuitePackage

public struct ExternalPDKRuleDeckInspector: PDKRuleDeckInspecting {
    private let provider: any PDKExternalRuleDeckResultProviding
    private let decoder: PDKExternalInspectionEnvelopeDecoder
    private let clock: any PDKStandardViewExecutionClock

    public init(
        provider: any PDKExternalRuleDeckResultProviding,
        decoder: PDKExternalInspectionEnvelopeDecoder = PDKExternalInspectionEnvelopeDecoder(),
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock()
    ) {
        self.provider = provider
        self.decoder = decoder
        self.clock = clock
    }

    public func execute(
        _ request: PDKRuleDeckInspectionRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKRuleDeckInspectionPayload> {
        let startedAt = clock.now()
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
            try validate(payload: envelope.payload, status: envelope.status, request: request)
            return envelope
        } catch let error as PDKExternalInspectionError {
            let status: XcircuiteEngineExecutionStatus = isTrustBoundaryError(error) ? .blocked : .failed
            return failureEnvelope(
                request: request,
                startedAt: startedAt,
                status: status,
                finding: finding(
                    code: "pdk.external.rule-deck-contract-mismatch",
                    message: error.localizedDescription,
                    severity: status == .blocked ? .blocker : .error,
                    actions: ["repair_external_result_envelope", "rerun_external_rule_deck"]
                )
            )
        } catch {
            return failureEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
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
    }

    private func isTrustBoundaryError(_ error: PDKExternalInspectionError) -> Bool {
        switch error {
        case .schemaVersionMismatch, .runIDMismatch, .assetIDMismatch, .pdkDigestMismatch:
            true
        case .invalidJSON, .standardViewFormatMismatch, .completedPayloadInvalid:
            false
        }
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
        finding: PDKValidationFinding
    ) -> XcircuiteEngineResultEnvelope<PDKRuleDeckInspectionPayload> {
        XcircuiteEngineResultEnvelope(
            schemaVersion: PDKRuleDeckInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: [PDKStandardViewDiagnosticMapper.map(finding)],
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
}
