import Foundation
import PDKCore

public struct PDKCorpusRuleDeckResult: Sendable, Hashable, Codable {
    public var assetID: String
    public var expectedOutcome: PDKCorpusExpectedOutcome
    public var observedOutcome: PDKCorpusExpectedOutcome
    public var passed: Bool
    public var expectedFindingCodes: [String]
    public var observedFindingCodes: [String]
    public var missingExpectedFindingCodes: [String]

    public init(
        assetID: String,
        expectedOutcome: PDKCorpusExpectedOutcome,
        observedOutcome: PDKCorpusExpectedOutcome,
        passed: Bool,
        expectedFindingCodes: [String] = [],
        observedFindingCodes: [String] = [],
        missingExpectedFindingCodes: [String] = []
    ) {
        self.assetID = assetID
        self.expectedOutcome = expectedOutcome
        self.observedOutcome = observedOutcome
        self.passed = passed
        self.expectedFindingCodes = expectedFindingCodes
        self.observedFindingCodes = observedFindingCodes
        self.missingExpectedFindingCodes = missingExpectedFindingCodes
    }
}
