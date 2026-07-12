import Foundation
import PDKCore

public struct PDKCorpusValidationPayload: Sendable, Hashable, Codable {
    public var suiteID: String
    public var processID: String
    public var version: String
    public var isValid: Bool
    public var caseResults: [PDKCorpusCaseResult]
    public var suiteFindings: [PDKValidationFinding]
    public var caseCount: Int
    public var passedCaseCount: Int
    public var failedCaseCount: Int
    public var limitations: [String]

    public init(
        suiteID: String,
        processID: String,
        version: String,
        isValid: Bool,
        caseResults: [PDKCorpusCaseResult],
        suiteFindings: [PDKValidationFinding] = [],
        limitations: [String] = []
    ) {
        self.suiteID = suiteID
        self.processID = processID
        self.version = version
        self.isValid = isValid
        self.caseResults = caseResults
        self.suiteFindings = suiteFindings
        self.caseCount = caseResults.count
        self.passedCaseCount = caseResults.filter(\.passed).count
        self.failedCaseCount = caseResults.filter { !$0.passed }.count
        self.limitations = limitations
    }
}
