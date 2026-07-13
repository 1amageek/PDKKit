import Foundation
import PDKCore
import PDKStandardViews
import CircuiteFoundation

public struct LocalPDKCorpusValidator: PDKCorpusValidating {
    private let clock: any PDKValidationExecutionClock
    private let suiteCodec: PDKCorpusSuiteCodec
    private let suiteValidator: PDKCorpusSuiteValidator
    private let referenceBuilder: PDKManifestReferenceBuilder
    private let validator: any PDKValidating
    private let standardViewInspector: any PDKManifestViewInspecting
    private let ruleDeckInspector: any PDKRuleDeckInspecting

    public init(
        clock: any PDKValidationExecutionClock = SystemPDKValidationExecutionClock(),
        suiteCodec: PDKCorpusSuiteCodec = PDKCorpusSuiteCodec(),
        suiteValidator: PDKCorpusSuiteValidator = PDKCorpusSuiteValidator(),
        referenceBuilder: PDKManifestReferenceBuilder = PDKManifestReferenceBuilder(),
        validator: any PDKValidating = LocalPDKValidator(),
        standardViewInspector: any PDKManifestViewInspecting = LocalPDKManifestViewInspector(),
        ruleDeckInspector: any PDKRuleDeckInspecting = LocalPDKRuleDeckInspector()
    ) {
        self.clock = clock
        self.suiteCodec = suiteCodec
        self.suiteValidator = suiteValidator
        self.referenceBuilder = referenceBuilder
        self.validator = validator
        self.standardViewInspector = standardViewInspector
        self.ruleDeckInspector = ruleDeckInspector
    }

    public func execute(
        _ request: PDKCorpusValidationRequest
    ) async throws -> PDKCorpusValidationExecutionResult {
        let startedAt = clock.now()
        let suiteURL = URL(filePath: request.suitePath).standardizedFileURL
        let rootURL = URL(filePath: request.rootPath).standardizedFileURL

        guard FileManager.default.fileExists(atPath: suiteURL.path) else {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.corpus.suite-missing",
                message: "PDK corpus suite does not exist at the referenced path.",
                entity: suiteURL.path,
                suggestedActions: ["restore_pdk_corpus_suite"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                diagnostics: [PDKValidationDiagnosticMapper.map(finding)],
                payload: PDKCorpusValidationPayload(
                    suiteID: "unavailable",
                    processID: "",
                    version: "",
                    isValid: false,
                    caseResults: [],
                    suiteFindings: [finding],
                    limitations: ["The corpus suite could not be loaded."]
                )
            )
        }

        let suite: PDKCorpusSuite
        do {
            suite = try suiteCodec.decode(contentsOf: suiteURL)
        } catch {
            let finding = PDKValidationFinding(
                severity: .error,
                code: "pdk.corpus.suite-decode-failed",
                message: "PDK corpus suite could not be decoded: \(error)",
                entity: suiteURL.path,
                suggestedActions: ["repair_pdk_corpus_suite", "run_pdkkit_corpus_help"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                diagnostics: [PDKValidationDiagnosticMapper.map(finding)],
                payload: PDKCorpusValidationPayload(
                    suiteID: "unavailable",
                    processID: "",
                    version: "",
                    isValid: false,
                    caseResults: [],
                    suiteFindings: [finding],
                    limitations: ["The corpus suite could not be interpreted."]
                )
            )
        }

        let suiteReport = suiteValidator.validate(suite)
        guard suiteReport.isValid else {
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                diagnostics: suiteReport.findings.map(PDKValidationDiagnosticMapper.map),
                payload: PDKCorpusValidationPayload(
                    suiteID: suite.suiteID,
                    processID: suite.processID,
                    version: suite.version,
                    isValid: false,
                    caseResults: [],
                    suiteFindings: suiteReport.findings,
                    limitations: ["The corpus suite contract is invalid; no case was executed."]
                )
            )
        }

        var caseResults: [PDKCorpusCaseResult] = []
        var diagnostics = suiteReport.findings.map(PDKValidationDiagnosticMapper.map)
        for corpusCase in suite.cases.sorted(by: { $0.caseID < $1.caseID }) {
            let result = await evaluate(
                corpusCase,
                rootURL: rootURL,
                runID: request.runID
            )
            caseResults.append(result)
            if !result.passed {
                diagnostics.append(DesignDiagnostic(
                    severity: .error,
                    code: "pdk.corpus.case-mismatch",
                    message: "Corpus case did not produce its expected outcome or findings.",
                    entity: result.caseID,
                    suggestedActions: ["inspect_pdk_corpus_case", "update_validator_or_fixture"]
                ))
            }
        }

        let isValid = caseResults.allSatisfy(\.passed)
        let status: PDKExecutionStatus = isValid ? .completed : .failed
        return makeEnvelope(
            request: request,
            startedAt: startedAt,
            status: status,
            diagnostics: diagnostics,
            artifacts: caseResults.compactMap { $0.manifestReference?.locator },
            payload: PDKCorpusValidationPayload(
                suiteID: suite.suiteID,
                processID: suite.processID,
                version: suite.version,
                isValid: isValid,
                caseResults: caseResults,
                suiteFindings: suiteReport.findings,
                limitations: [
                    "Corpus success proves only the declared local cases and validator contract.",
                    "Corpus success does not establish standard-format correctness or foundry qualification."
                ]
            )
        )
    }

    private func evaluate(
        _ corpusCase: PDKCorpusCase,
        rootURL: URL,
        runID: String
    ) async -> PDKCorpusCaseResult {
        let manifestURL = rootURL.appending(path: corpusCase.manifestPath).standardizedFileURL
        guard isWithinRoot(manifestURL, rootURL: rootURL) else {
            return caseResult(
                corpusCase,
                observedOutcome: .blocked,
                observedFindingCodes: ["pdk.corpus.unsafe-manifest-path"]
            )
        }
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return caseResult(
                corpusCase,
                observedOutcome: .blocked,
                observedFindingCodes: ["pdk.corpus.manifest-missing"]
            )
        }

        let reference: PDKReference
        do {
            reference = try referenceBuilder.makeReference(for: manifestURL)
        } catch {
            return caseResult(
                corpusCase,
                observedOutcome: .failed,
                observedFindingCodes: ["pdk.corpus.reference-build-failed"]
            )
        }

        let validationRequest = PDKValidationRequest(
            runID: runID + ":" + corpusCase.caseID,
            inputs: [reference.manifest.locator],
            pdk: reference,
            requiredAssetRoles: corpusCase.requiredAssetRoles,
            validateCrossViews: corpusCase.validateCrossViews
        )
        do {
            let envelope = try await validator.execute(validationRequest)
            let observedOutcome = outcome(for: envelope.status)
            let envelopeDiagnosticCodes: [String] = envelope.diagnostics.map { $0.code.rawValue }
            let envelopeFindingCodes: [String] = envelope.payload.findings.map { $0.code }
            var observedFindingCodes: Set<String> = Set(envelopeDiagnosticCodes + envelopeFindingCodes)
            var standardViewResults: [PDKCorpusStandardViewResult] = []
            var ruleDeckResults: [PDKCorpusRuleDeckResult] = []
            if envelope.status == .completed {
                for check in corpusCase.standardViewChecks {
                    let standardResult: PDKCorpusStandardViewResult
                    guard let format = PDKStandardViewFormat(rawValue: check.format) else {
                        standardResult = standardViewResult(
                            check,
                            observedOutcome: .failed,
                            observedFindingCodes: ["pdk.corpus.unsupported-standard-view-format"]
                        )
                        standardViewResults.append(standardResult)
                        observedFindingCodes.formUnion(standardResult.observedFindingCodes)
                        continue
                    }
                    let inspectionRequest = PDKManifestViewInspectionRequest(
                        runID: runID + ":" + corpusCase.caseID + ":" + check.assetID + ":" + check.format,
                        inputs: [reference.manifest.locator],
                        pdk: reference,
                        assetID: check.assetID,
                        format: format
                    )
                    do {
                        let inspectionEnvelope = try await standardViewInspector.execute(inspectionRequest)
                        let diagnosticCodes: [String] = inspectionEnvelope.diagnostics.map { $0.code.rawValue }
                        let findingCodes: [String] = inspectionEnvelope.payload.findings.map { $0.code }
                        let codes: Set<String> = Set(diagnosticCodes + findingCodes)
                        standardResult = standardViewResult(
                            check,
                            observedOutcome: outcome(for: inspectionEnvelope.status),
                            observedFindingCodes: codes.sorted()
                        )
                    } catch {
                        standardResult = standardViewResult(
                            check,
                            observedOutcome: .failed,
                            observedFindingCodes: ["pdk.corpus.standard-view-execution-failed"]
                        )
                    }
                    standardViewResults.append(standardResult)
                    observedFindingCodes.formUnion(standardResult.observedFindingCodes)
                }
            }
            for check in corpusCase.ruleDeckChecks {
                let deckResult: PDKCorpusRuleDeckResult
                let inspectionRequest = PDKRuleDeckInspectionRequest(
                    runID: runID + ":" + corpusCase.caseID + ":" + check.assetID + ":rule-deck",
                    inputs: [reference.manifest.locator],
                    pdk: reference,
                    assetID: check.assetID
                )
                do {
                    let inspectionEnvelope = try await ruleDeckInspector.execute(inspectionRequest)
                    let diagnosticCodes: [String] = inspectionEnvelope.diagnostics.map { $0.code.rawValue }
                    let findingCodes: [String] = inspectionEnvelope.payload.findings.map { $0.code }
                    let codes: Set<String> = Set(diagnosticCodes + findingCodes)
                    deckResult = ruleDeckResult(
                        check,
                        observedOutcome: outcome(for: inspectionEnvelope.status),
                        observedFindingCodes: codes.sorted()
                    )
                } catch {
                    deckResult = ruleDeckResult(
                        check,
                        observedOutcome: .failed,
                        observedFindingCodes: ["pdk.corpus.rule-deck-execution-failed"]
                    )
                }
                ruleDeckResults.append(deckResult)
                observedFindingCodes.formUnion(deckResult.observedFindingCodes)
            }
            return caseResult(
                corpusCase,
                observedOutcome: observedOutcome,
                observedFindingCodes: observedFindingCodes.sorted(),
                standardViewResults: standardViewResults,
                ruleDeckResults: ruleDeckResults,
                manifestReference: reference.manifest
            )
        } catch {
            return caseResult(
                corpusCase,
                observedOutcome: .failed,
                observedFindingCodes: ["pdk.corpus.case-execution-failed"],
                manifestReference: reference.manifest
            )
        }
    }

    private func caseResult(
        _ corpusCase: PDKCorpusCase,
        observedOutcome: PDKCorpusExpectedOutcome,
        observedFindingCodes: [String],
        standardViewResults: [PDKCorpusStandardViewResult] = [],
        ruleDeckResults: [PDKCorpusRuleDeckResult] = [],
        manifestReference: ArtifactReference? = nil
    ) -> PDKCorpusCaseResult {
        let expectedCodes = Set(corpusCase.expectedFindingCodes)
        let observedCodes = Set(observedFindingCodes)
        let missingCodes = expectedCodes.subtracting(observedCodes).sorted()
        return PDKCorpusCaseResult(
            caseID: corpusCase.caseID,
            manifestPath: corpusCase.manifestPath,
            expectedOutcome: corpusCase.expectedOutcome,
            observedOutcome: observedOutcome,
            passed: corpusCase.expectedOutcome == observedOutcome &&
                missingCodes.isEmpty &&
                standardViewResults.allSatisfy(\.passed) &&
                ruleDeckResults.allSatisfy(\.passed),
            expectedFindingCodes: corpusCase.expectedFindingCodes,
            observedFindingCodes: observedFindingCodes.sorted(),
            missingExpectedFindingCodes: missingCodes,
            standardViewResults: standardViewResults,
            ruleDeckResults: ruleDeckResults,
            manifestReference: manifestReference
        )
    }

    private func standardViewResult(
        _ check: PDKCorpusStandardViewCheck,
        observedOutcome: PDKCorpusExpectedOutcome,
        observedFindingCodes: [String]
    ) -> PDKCorpusStandardViewResult {
        let expectedCodes = Set(check.expectedFindingCodes)
        let observedCodes = Set(observedFindingCodes)
        return PDKCorpusStandardViewResult(
            assetID: check.assetID,
            format: check.format,
            expectedOutcome: check.expectedOutcome,
            observedOutcome: observedOutcome,
            passed: check.expectedOutcome == observedOutcome && expectedCodes.isSubset(of: observedCodes),
            expectedFindingCodes: check.expectedFindingCodes,
            observedFindingCodes: observedCodes.sorted(),
            missingExpectedFindingCodes: expectedCodes.subtracting(observedCodes).sorted()
        )
    }

    private func ruleDeckResult(
        _ check: PDKCorpusRuleDeckCheck,
        observedOutcome: PDKCorpusExpectedOutcome,
        observedFindingCodes: [String]
    ) -> PDKCorpusRuleDeckResult {
        let expectedCodes = Set(check.expectedFindingCodes)
        let observedCodes = Set(observedFindingCodes)
        return PDKCorpusRuleDeckResult(
            assetID: check.assetID,
            expectedOutcome: check.expectedOutcome,
            observedOutcome: observedOutcome,
            passed: check.expectedOutcome == observedOutcome && expectedCodes.isSubset(of: observedCodes),
            expectedFindingCodes: check.expectedFindingCodes,
            observedFindingCodes: observedCodes.sorted(),
            missingExpectedFindingCodes: expectedCodes.subtracting(observedCodes).sorted()
        )
    }

    private func outcome(for status: PDKExecutionStatus) -> PDKCorpusExpectedOutcome {
        switch status {
        case .completed: .valid
        case .blocked: .blocked
        case .failed, .cancelled: .failed
        }
    }

    private func isWithinRoot(_ url: URL, rootURL: URL) -> Bool {
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        return url.path == rootURL.path || url.path.hasPrefix(rootPath)
    }

    private func makeEnvelope(
        request: PDKCorpusValidationRequest,
        startedAt: Date,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic],
        artifacts: [ArtifactLocator] = [],
        payload: PDKCorpusValidationPayload
    ) -> PDKCorpusValidationExecutionResult {
        PDKCorpusValidationExecutionResult(
            schemaVersion: PDKCorpusValidationRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: diagnostics,
            artifacts: artifacts,
            metadata: PDKExecutionMetadata(
                engineID: "PDKCorpusValidation",
                implementationID: "LocalPDKCorpusValidator",
                implementationVersion: "1",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: payload
        )
    }
}
