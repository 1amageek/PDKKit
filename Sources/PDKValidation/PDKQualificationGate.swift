import Foundation
import PDKCore
import PDKStandardViews

public struct PDKQualificationGate: PDKQualificationGating {
    public init() {}

    public func evaluate(
        pdk: PDKReference,
        corpus: PDKCorpusValidationPayload,
        oracle: PDKOracleComparisonPayload
    ) -> PDKQualificationAssessment {
        var findings: [PDKValidationFinding] = []
        let matchingManifestEvidence = corpus.caseResults.contains { result in
            result.manifestReference?.sha256?.caseInsensitiveCompare(pdk.digest) == .orderedSame
        }
        if !corpus.isValid {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.qualification.corpus-not-valid",
                message: "Retained corpus evidence did not pass all declared cases.",
                entity: corpus.suiteID,
                suggestedActions: ["repair_pdk_corpus", "rerun_pdkkit_corpus"]
            ))
        }
        if corpus.processID != pdk.processID {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.qualification.corpus-process-id-mismatch",
                message: "Retained corpus evidence belongs to a different process ID.",
                entity: corpus.suiteID,
                suggestedActions: ["rerun_pdkkit_corpus", "select_matching_pdk_manifest"]
            ))
        }
        if corpus.version != pdk.version {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.qualification.corpus-version-mismatch",
                message: "Retained corpus evidence belongs to a different PDK version.",
                entity: corpus.suiteID,
                suggestedActions: ["rerun_pdkkit_corpus", "select_matching_pdk_manifest"]
            ))
        }
        if !matchingManifestEvidence {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.qualification.corpus-pdk-digest-missing",
                message: "Retained corpus evidence is not bound to the selected PDK manifest digest.",
                entity: pdk.digest,
                suggestedActions: ["rerun_pdkkit_corpus", "select_matching_pdk_manifest"]
            ))
        }
        if !oracle.isValid {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.qualification.oracle-not-valid",
                message: "Oracle comparison did not pass all declared standard-view expectations.",
                entity: oracle.oracleID,
                suggestedActions: ["repair_standard_view_artifact", "rerun_pdkkit_oracle"]
            ))
        }
        if oracle.pdkDigest.caseInsensitiveCompare(pdk.digest) != .orderedSame {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.qualification.oracle-pdk-digest-mismatch",
                message: "Oracle evidence is bound to a different PDK manifest digest.",
                entity: oracle.oracleID,
                suggestedActions: ["rebuild_oracle_expectation", "select_matching_pdk_manifest"]
            ))
        }
        if oracle.comparisons.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.qualification.oracle-comparisons-missing",
                message: "Oracle evidence contains no standard-view comparisons.",
                entity: oracle.oracleID,
                suggestedActions: ["declare_oracle_views", "rerun_pdkkit_oracle"]
            ))
        }

        let isValid = findings.isEmpty
        return PDKQualificationAssessment(
            isValid: isValid,
            state: isValid ? .oracleCorrelated : .unverified,
            processID: pdk.processID,
            version: pdk.version,
            pdkDigest: pdk.digest,
            corpusID: corpus.suiteID,
            oracleID: oracle.oracleID,
            evidenceIDs: [
                "pdk-manifest:\(pdk.digest)",
                "pdk-corpus:\(corpus.suiteID)",
                "pdk-oracle:\(oracle.oracleID)"
            ],
            findings: findings,
            limitations: [
                "oracleCorrelated means local canonical facts matched an immutable expectation fixture.",
                "processQualified remains unavailable until independent process qualification and human approval are attached."
            ]
        )
    }
}
