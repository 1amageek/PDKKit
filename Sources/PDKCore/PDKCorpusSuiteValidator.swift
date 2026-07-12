import Foundation

public struct PDKCorpusSuiteValidator: Sendable {
    public init() {}

    public func validate(_ suite: PDKCorpusSuite) -> PDKCorpusSuiteValidationReport {
        var findings: [PDKValidationFinding] = []
        if suite.schemaVersion != PDKCorpusSuite.currentSchemaVersion {
            findings.append(blocker(
                "pdk.corpus.unsupported-schema-version",
                "Corpus suite schema version is not the current supported version.",
                "schemaVersion"
            ))
        }
        requireNonEmpty(suite.suiteID, field: "suiteID", findings: &findings)
        requireNonEmpty(suite.processID, field: "processID", findings: &findings)
        requireNonEmpty(suite.version, field: "version", findings: &findings)
        if suite.cases.isEmpty {
            findings.append(blocker(
                "pdk.corpus.cases-missing",
                "Corpus suite must contain at least one case.",
                "cases"
            ))
        }

        var caseIDs = Set<String>()
        for corpusCase in suite.cases {
            if !caseIDs.insert(corpusCase.caseID).inserted {
                findings.append(blocker(
                    "pdk.corpus.duplicate-case-id",
                    "Corpus case identifiers must be unique.",
                    corpusCase.caseID
                ))
            }
            requireNonEmpty(corpusCase.caseID, field: "caseID", entity: "cases", findings: &findings)
            if corpusCase.manifestPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(blocker(
                    "pdk.corpus.manifest-path-missing",
                    "Corpus cases must reference a manifest path.",
                    corpusCase.caseID
                ))
            } else if isUnsafeRelativePath(corpusCase.manifestPath) {
                findings.append(blocker(
                    "pdk.corpus.unsafe-manifest-path",
                    "Corpus manifest paths must remain relative to the corpus root.",
                    corpusCase.caseID
                ))
            }
            for code in corpusCase.expectedFindingCodes where code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(blocker(
                    "pdk.corpus.empty-finding-code",
                    "Expected finding codes must not be empty.",
                    corpusCase.caseID
                ))
            }
            var standardViewKeys = Set<String>()
            for check in corpusCase.standardViewChecks {
                requireNonEmpty(check.assetID, field: "standardViewAssetID", entity: corpusCase.caseID, findings: &findings)
                requireNonEmpty(check.format, field: "standardViewFormat", entity: corpusCase.caseID, findings: &findings)
                let key = "\(check.assetID):\(check.format)"
                if !standardViewKeys.insert(key).inserted {
                    findings.append(blocker(
                        "pdk.corpus.duplicate-standard-view-check",
                        "Standard-view checks must not repeat the same asset and format pair.",
                        corpusCase.caseID
                    ))
                }
                guard ["lef", "gdsii", "oasis", "spice", "liberty"].contains(check.format) else {
                    findings.append(blocker(
                        "pdk.corpus.unsupported-standard-view-format",
                        "Standard-view checks must use a supported format.",
                        check.format
                    ))
                    continue
                }
                for code in check.expectedFindingCodes where code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    findings.append(blocker(
                        "pdk.corpus.empty-standard-view-finding-code",
                        "Expected standard-view finding codes must not be empty.",
                        corpusCase.caseID
                    ))
                }
            }
        }

        return PDKCorpusSuiteValidationReport(
            isValid: !findings.contains { $0.severity == .blocker || $0.severity == .error },
            findings: findings
        )
    }

    private func requireNonEmpty(
        _ value: String,
        field: String,
        entity: String? = nil,
        findings: inout [PDKValidationFinding]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(blocker(
                "pdk.corpus.\(field)-missing",
                "\(field) must not be empty.",
                entity ?? field
            ))
        }
    }

    private func isUnsafeRelativePath(_ path: String) -> Bool {
        path.hasPrefix("/") ||
            path == ".." ||
            path.hasPrefix("../") ||
            path.contains("/../") ||
            path.contains("\\")
    }

    private func blocker(_ code: String, _ message: String, _ entity: String?) -> PDKValidationFinding {
        PDKValidationFinding(
            severity: .blocker,
            code: code,
            message: message,
            entity: entity,
            suggestedActions: ["repair_pdk_corpus_suite"]
        )
    }
}
