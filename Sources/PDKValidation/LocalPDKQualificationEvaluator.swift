import Foundation
import CircuiteFoundation
import PDKCore
import PDKStandardViews
import XcircuitePackage

public struct LocalPDKQualificationEvaluator: PDKQualificationExecuting {
    private let clock: any PDKValidationExecutionClock
    private let gate: any PDKQualificationGating

    public init(
        clock: any PDKValidationExecutionClock = SystemPDKValidationExecutionClock(),
        gate: any PDKQualificationGating = PDKQualificationGate()
    ) {
        self.clock = clock
        self.gate = gate
    }

    public func execute(
        _ request: PDKQualificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKQualificationAssessment> {
        let startedAt = clock.now()
        do {
            let corpus = try loadPayload(
                PDKCorpusValidationPayload.self,
                from: request.corpusReport,
                baseDirectoryPath: request.projectRootPath
            )
            let oracle = try loadPayload(
                PDKOracleComparisonPayload.self,
                from: request.oracleReport,
                baseDirectoryPath: request.projectRootPath
            )
            let assessment = gate.evaluate(pdk: request.pdk, corpus: corpus, oracle: oracle)
            let status: XcircuiteEngineExecutionStatus = assessment.isValid ? .completed : .blocked
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: status,
                assessment: assessment
            )
        } catch let error as PDKQualificationArtifactError {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.qualification.artifact-invalid",
                message: error.localizedDescription,
                entity: request.runID,
                suggestedActions: ["restore_qualification_artifact", "rerun_pdkkit_corpus", "rerun_pdkkit_oracle"]
            )
            let assessment = PDKQualificationAssessment(
                isValid: false,
                state: .unverified,
                processID: request.pdk.processID,
                version: request.pdk.version,
                pdkDigest: request.pdk.digest,
                findings: [finding],
                limitations: [
                    "Qualification cannot proceed without immutable corpus and oracle payload artifacts."
                ]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                assessment: assessment
            )
        }
    }

    private func loadPayload<Payload: Codable & Hashable & Sendable>(
        _ type: Payload.Type,
        from reference: XcircuiteFileReference,
        baseDirectoryPath: String?
    ) throws -> Payload {
        let url: URL
        do {
            url = try PDKArtifactURLResolver().resolve(
                reference,
                baseDirectoryPath: baseDirectoryPath
            )
        } catch {
            throw PDKQualificationArtifactError.invalidPath(
                path: reference.path,
                reason: error.localizedDescription
            )
        }
        let artifact: ArtifactReference
        do {
            artifact = try PDKFoundationArtifactBridge.artifactReference(
                for: reference,
                resolvedURL: url
            )
        } catch {
            throw PDKQualificationArtifactError.integrity(
                path: url.path,
                reason: "Artifact identity could not be constructed: \(error.localizedDescription)"
            )
        }
        let integrity = LocalArtifactVerifier().verify(artifact)
        guard integrity.isVerified else {
            throw PDKQualificationArtifactError.integrity(
                path: url.path,
                reason: integrity.issues.map { $0.code.rawValue }.joined(separator: ", ")
            )
        }
        guard artifact.byteCount <= UInt64(Int64.max) else {
            throw PDKQualificationArtifactError.integrity(
                path: url.path,
                reason: "byte count cannot be represented by the qualification artifact contract"
            )
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PDKQualificationArtifactError.unreadable(
                path: url.path,
                reason: error.localizedDescription
            )
        }
        guard Int64(data.count) == Int64(artifact.byteCount) else {
            throw PDKQualificationArtifactError.integrity(
                path: url.path,
                reason: "byte count does not match the reference"
            )
        }
        do {
            return try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            do {
                let envelope = try JSONDecoder().decode(
                    XcircuiteEngineResultEnvelope<Payload>.self,
                    from: data
                )
                return envelope.payload
            } catch {
                throw PDKQualificationArtifactError.decode(
                    path: url.path,
                    reason: error.localizedDescription
                )
            }
        }
    }

    private func makeEnvelope(
        request: PDKQualificationRequest,
        startedAt: Date,
        status: XcircuiteEngineExecutionStatus,
        assessment: PDKQualificationAssessment
    ) -> XcircuiteEngineResultEnvelope<PDKQualificationAssessment> {
        XcircuiteEngineResultEnvelope(
            schemaVersion: PDKQualificationRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: assessment.findings.map(PDKValidationDiagnosticMapper.map),
            artifacts: [request.pdk.manifest, request.corpusReport, request.oracleReport],
            metadata: XcircuiteEngineExecutionMetadata(
                engineID: "PDKQualification",
                implementationID: "LocalPDKQualificationEvaluator",
                implementationVersion: "1",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: assessment
        )
    }
}
