import Foundation
import PDKCore
import XcircuitePackage

public struct LocalPDKOracleComparator: PDKOracleComparing {
    private let clock: any PDKStandardViewExecutionClock
    private let manifestInspector: any PDKManifestViewInspecting

    public init(
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock(),
        manifestInspector: any PDKManifestViewInspecting = LocalPDKManifestViewInspector()
    ) {
        self.clock = clock
        self.manifestInspector = manifestInspector
    }

    public func execute(
        _ request: PDKOracleRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKOracleComparisonPayload> {
        let startedAt = clock.now()
        let oracleURL: URL
        do {
            oracleURL = try PDKArtifactURLResolver().resolve(
                request.oracle,
                baseDirectoryPath: request.projectRootPath
            )
        } catch {
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                oracleID: "unavailable",
                findings: [PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.oracle.input-path-invalid",
                    message: "Oracle expectation path could not be resolved: \(error.localizedDescription)",
                    entity: request.oracle.path,
                    suggestedActions: ["provide_project_root", "repair_oracle_reference"]
                )]
            )
        }
        let data: Data
        do {
            data = try Data(contentsOf: oracleURL)
        } catch {
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                oracleID: "unavailable",
                findings: [PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.oracle.input-unreadable",
                    message: "Oracle expectation could not be read: \(error.localizedDescription)",
                    entity: oracleURL.path,
                    suggestedActions: ["restore_oracle_expectation", "check_file_permissions"]
                )]
            )
        }

        var integrityFindings = verifyIntegrity(data: data, reference: request.oracle)
        guard !integrityFindings.contains(where: { $0.severity == .blocker || $0.severity == .error }) else {
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                oracleID: "unavailable",
                findings: integrityFindings
            )
        }

        let expectation: PDKOracleExpectation
        do {
            expectation = try JSONDecoder().decode(PDKOracleExpectation.self, from: data)
        } catch {
            integrityFindings.append(PDKValidationFinding(
                severity: .error,
                code: "pdk.oracle.decode-failed",
                message: "Oracle expectation could not be decoded: \(error)",
                entity: oracleURL.path,
                suggestedActions: ["repair_oracle_expectation", "run_pdkkit_oracle_help"]
            ))
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                oracleID: "unavailable",
                findings: integrityFindings
            )
        }

        var findings = validateExpectation(expectation: expectation, request: request)
        guard !findings.contains(where: { $0.severity == .blocker || $0.severity == .error }) else {
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                oracleID: expectation.oracleID,
                findings: findings
            )
        }

        var comparisons: [PDKOracleViewComparison] = []
        var hasBlockedView = false
        var hasFailedView = false
        for view in expectation.views {
            let inspectionRequest = PDKManifestViewInspectionRequest(
                runID: request.runID + ":" + view.assetID + ":" + view.format.rawValue,
                inputs: [request.pdk.manifest],
                pdk: request.pdk,
                assetID: view.assetID,
                format: view.format,
                projectRootPath: request.projectRootPath
            )
            do {
                let envelope = try await manifestInspector.execute(inspectionRequest)
                let inspectionFindings = envelope.payload.findings
                findings.append(contentsOf: inspectionFindings)
                switch envelope.status {
                case .failed, .cancelled:
                    hasFailedView = true
                case .blocked:
                    hasBlockedView = true
                case .completed:
                    break
                }
                guard let inspection = envelope.payload.inspection?.inspection else {
                    let missingInspection = PDKValidationFinding(
                        severity: .error,
                        code: "pdk.oracle.inspection-missing",
                        message: "Manifest-bound inspection did not return canonical standard-view facts.",
                        entity: view.assetID,
                        suggestedActions: ["repair_standard_view_artifact", "rerun_manifest_view_inspection"]
                    )
                    findings.append(missingInspection)
                    comparisons.append(PDKOracleViewComparison(
                        assetID: view.assetID,
                        format: view.format,
                        isMatch: false,
                        findings: [missingInspection]
                    ))
                    hasFailedView = true
                    continue
                }
                let comparison = compare(expected: view, observed: inspection)
                comparisons.append(comparison)
                findings.append(contentsOf: comparison.findings)
            } catch {
                let executionFinding = PDKValidationFinding(
                    severity: .error,
                    code: "pdk.oracle.view-execution-failed",
                    message: "Manifest-bound inspection failed: \(error)",
                    entity: view.assetID,
                    suggestedActions: ["inspect_standard_view_artifact", "rerun_pdkkit_oracle"]
                )
                findings.append(executionFinding)
                comparisons.append(PDKOracleViewComparison(
                    assetID: view.assetID,
                    format: view.format,
                    isMatch: false,
                    findings: [executionFinding]
                ))
                hasFailedView = true
            }
        }

        let hasMismatch = comparisons.contains { !$0.isMatch }
        let status: XcircuiteEngineExecutionStatus
        if hasFailedView {
            status = .failed
        } else if hasBlockedView || hasMismatch {
            status = .blocked
        } else {
            status = .completed
        }
        return makeEnvelope(
            request: request,
            startedAt: startedAt,
            status: status,
            oracleID: expectation.oracleID,
            findings: findings,
            comparisons: comparisons
        )
    }

    private func verifyIntegrity(
        data: Data,
        reference: XcircuiteFileReference
    ) -> [PDKValidationFinding] {
        var findings: [PDKValidationFinding] = []
        guard let expectedDigest = reference.sha256, !expectedDigest.isEmpty else {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.oracle.digest-missing",
                message: "Oracle expectation must carry a SHA-256 digest.",
                entity: reference.path,
                suggestedActions: ["rebuild_oracle_reference"]
            ))
            return findings
        }
        guard let expectedByteCount = reference.byteCount else {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.oracle.byte-count-missing",
                message: "Oracle expectation must carry a byte count.",
                entity: reference.path,
                suggestedActions: ["rebuild_oracle_reference"]
            ))
            return findings
        }
        do {
            let actualDigest = try SHA256PDKDigestor().digest(data: data)
            if actualDigest != expectedDigest.lowercased() {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.oracle.digest-mismatch",
                    message: "Oracle expectation bytes do not match the recorded SHA-256 digest.",
                    entity: reference.path,
                    suggestedActions: ["rebuild_oracle_reference", "restore_immutable_artifact"]
                ))
            }
        } catch {
            findings.append(PDKValidationFinding(
                severity: .error,
                code: "pdk.oracle.hash-failed",
                message: "Oracle expectation could not be hashed: \(error.localizedDescription)",
                entity: reference.path,
                suggestedActions: ["check_file_permissions"]
            ))
        }
        if Int64(data.count) != expectedByteCount {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.oracle.byte-count-mismatch",
                message: "Oracle expectation bytes do not match the recorded byte count.",
                entity: reference.path,
                suggestedActions: ["rebuild_oracle_reference", "restore_immutable_artifact"]
            ))
        }
        return findings
    }

    private func validateExpectation(
        expectation: PDKOracleExpectation,
        request: PDKOracleRequest
    ) -> [PDKValidationFinding] {
        var findings: [PDKValidationFinding] = []
        if expectation.oracleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(invalidExpectation("oracleID must not be empty", entity: "oracleID"))
        }
        if expectation.processID != request.pdk.processID {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.oracle.process-id-mismatch",
                message: "Oracle process ID does not match the PDK reference.",
                entity: "processID",
                suggestedActions: ["rebuild_oracle_expectation", "select_matching_pdk"]
            ))
        }
        if expectation.version != request.pdk.version {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.oracle.version-mismatch",
                message: "Oracle version does not match the PDK reference.",
                entity: "version",
                suggestedActions: ["rebuild_oracle_expectation", "select_matching_pdk"]
            ))
        }
        if expectation.pdkDigest.lowercased() != request.pdk.digest.lowercased() {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.oracle.pdk-digest-mismatch",
                message: "Oracle expectation is bound to a different PDK manifest digest.",
                entity: "pdkDigest",
                suggestedActions: ["rebuild_oracle_expectation", "restore_matching_pdk_manifest"]
            ))
        }
        if expectation.views.isEmpty {
            findings.append(invalidExpectation("views must contain at least one standard-view expectation", entity: "views"))
        }
        var keys = Set<String>()
        for view in expectation.views {
            let key = "\(view.assetID):\(view.format.rawValue)"
            if !keys.insert(key).inserted {
                findings.append(invalidExpectation("view expectations must be unique", entity: key))
            }
            if view.assetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(invalidExpectation("assetID must not be empty", entity: key))
            }
        }
        return findings
    }

    private func invalidExpectation(_ message: String, entity: String) -> PDKValidationFinding {
        PDKValidationFinding(
            severity: .blocker,
            code: "pdk.oracle.expectation-invalid",
            message: message,
            entity: entity,
            suggestedActions: ["repair_oracle_expectation"]
        )
    }

    private func compare(
        expected: PDKOracleViewExpectation,
        observed: PDKStandardViewIR
    ) -> PDKOracleViewComparison {
        var findings: [PDKValidationFinding] = []
        compareOptional(expected.expectedLibraryName, observed.libraryName, field: "libraryName", expected: expected, findings: &findings)
        compareOptional(expected.expectedLayerNames, observed.layerNames, field: "layerNames", expected: expected, findings: &findings)
        compareOptional(expected.expectedPhysicalLayerNumbers, observed.physicalLayerNumbers, field: "physicalLayerNumbers", expected: expected, findings: &findings)
        compareOptional(expected.expectedCellNames, observed.cellNames, field: "cellNames", expected: expected, findings: &findings)
        compareOptional(expected.expectedViaNames, observed.viaNames, field: "viaNames", expected: expected, findings: &findings)
        compareOptional(expected.expectedModelNames, observed.modelNames, field: "modelNames", expected: expected, findings: &findings)
        compareOptional(expected.expectedModelTypes, observed.modelTypes, field: "modelTypes", expected: expected, findings: &findings)
        compareOptional(expected.expectedModelParameterNames, observed.modelParameterNames, field: "modelParameterNames", expected: expected, findings: &findings)
        compareOptional(expected.expectedPinNames, observed.pinNames, field: "pinNames", expected: expected, findings: &findings)
        compareOptional(expected.expectedCornerNames, observed.cornerNames, field: "cornerNames", expected: expected, findings: &findings)
        compareOptional(expected.expectedTimingArcCount, observed.timingArcCount, field: "timingArcCount", expected: expected, findings: &findings)
        compareOptional(expected.expectedTimingRelatedPinNames, observed.timingRelatedPinNames, field: "timingRelatedPinNames", expected: expected, findings: &findings)
        compareOptional(expected.expectedTimingTableValueCount, observed.timingTableValueCount, field: "timingTableValueCount", expected: expected, findings: &findings)
        compareOptional(expected.expectedElementCount, observed.elementCount, field: "elementCount", expected: expected, findings: &findings)
        if let expectedMetadata = expected.expectedMetadata {
            for key in expectedMetadata.keys.sorted() {
                compareOptional(expectedMetadata[key], observed.metadata[key], field: "metadata.\(key)", expected: expected, findings: &findings)
            }
        }
        return PDKOracleViewComparison(
            assetID: expected.assetID,
            format: expected.format,
            isMatch: findings.isEmpty,
            observed: observed,
            findings: findings
        )
    }

    private func compareOptional<T: Equatable>(
        _ expectedValue: T?,
        _ observedValue: T?,
        field: String,
        expected: PDKOracleViewExpectation,
        findings: inout [PDKValidationFinding]
    ) {
        guard let expectedValue else { return }
        guard expectedValue != observedValue else { return }
        findings.append(PDKValidationFinding(
            severity: .blocker,
            code: "pdk.oracle.value-mismatch",
            message: "Oracle value mismatch for \(field): expected \(String(describing: expectedValue)), observed \(String(describing: observedValue)).",
            entity: "\(expected.assetID).\(field)",
            suggestedActions: ["inspect_standard_view_artifact", "repair_oracle_expectation"]
        ))
    }

    private func makeEnvelope(
        request: PDKOracleRequest,
        startedAt: Date,
        status: XcircuiteEngineExecutionStatus,
        oracleID: String,
        findings: [PDKValidationFinding],
        comparisons: [PDKOracleViewComparison] = []
    ) -> XcircuiteEngineResultEnvelope<PDKOracleComparisonPayload> {
        XcircuiteEngineResultEnvelope(
            schemaVersion: PDKOracleRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: findings.map(PDKStandardViewDiagnosticMapper.map),
            artifacts: [request.pdk.manifest, request.oracle],
            metadata: XcircuiteEngineExecutionMetadata(
                engineID: "PDKOracleComparison",
                implementationID: "LocalPDKOracleComparator",
                implementationVersion: "1",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: PDKOracleComparisonPayload(
                isValid: status == .completed,
                oracleID: oracleID,
                pdkDigest: request.pdk.digest,
                comparisons: comparisons,
                findings: findings,
                limitations: [
                    "Oracle comparison proves correlation against the declared immutable expectation fixture.",
                    "Oracle correlation does not establish foundry qualification without independent ToolQualification evidence."
                ]
            )
        )
    }
}
