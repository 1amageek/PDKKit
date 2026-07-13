import Foundation
import PDKCore
import XcircuitePackage

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
    ) async throws -> XcircuiteEngineResultEnvelope<PDKStandardViewInspectionPayload> {
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
                    code: "pdk.external.standard-view-provider-failed",
                    message: "External standard-view provider failed: " + error.localizedDescription,
                    severity: .error,
                    actions: ["inspect_external_tool_log", "rerun_external_standard_view"]
                )
            )
        }

        do {
            let envelope = try decoder.decode(
                data,
                payload: PDKStandardViewInspectionPayload.self,
                expectedSchemaVersion: PDKStandardViewInspectionRequest.currentSchemaVersion,
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
                    code: "pdk.external.standard-view-contract-mismatch",
                    message: error.localizedDescription,
                    severity: status == .blocked ? .blocker : .error,
                    actions: ["repair_external_result_envelope", "rerun_external_standard_view"]
                )
            )
        } catch {
            return failureEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
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
        status: XcircuiteEngineExecutionStatus,
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
        case .schemaVersionMismatch, .runIDMismatch, .assetIDMismatch, .standardViewFormatMismatch, .pdkDigestMismatch:
            true
        case .invalidJSON, .completedPayloadInvalid:
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
            entity: "external-standard-view",
            suggestedActions: actions
        )
    }

    private func failureEnvelope(
        request: PDKStandardViewInspectionRequest,
        startedAt: Date,
        status: XcircuiteEngineExecutionStatus,
        finding: PDKValidationFinding
    ) -> XcircuiteEngineResultEnvelope<PDKStandardViewInspectionPayload> {
        XcircuiteEngineResultEnvelope(
            schemaVersion: PDKStandardViewInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: [PDKStandardViewDiagnosticMapper.map(finding)],
            metadata: XcircuiteEngineExecutionMetadata(
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
                    "The external backend result was rejected at the shared envelope boundary.",
                    "External tool qualification and process scope are evaluated outside this adapter."
                ]
            )
        )
    }
}
