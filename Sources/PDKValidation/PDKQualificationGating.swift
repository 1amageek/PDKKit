import Foundation
import PDKCore
import PDKStandardViews

public protocol PDKQualificationGating: Sendable {
    func evaluate(
        pdk: PDKReference,
        corpus: PDKCorpusValidationPayload,
        oracle: PDKOracleComparisonPayload
    ) -> PDKQualificationAssessment
}
