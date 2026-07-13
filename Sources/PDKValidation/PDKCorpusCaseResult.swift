import Foundation
import PDKCore
import CircuiteFoundation

public struct PDKCorpusCaseResult: Sendable, Hashable, Codable {
    public var caseID: String
    public var manifestPath: String
    public var expectedOutcome: PDKCorpusExpectedOutcome
    public var observedOutcome: PDKCorpusExpectedOutcome
    public var passed: Bool
    public var expectedFindingCodes: [String]
    public var observedFindingCodes: [String]
    public var missingExpectedFindingCodes: [String]
    public var standardViewResults: [PDKCorpusStandardViewResult]
    public var ruleDeckResults: [PDKCorpusRuleDeckResult]
    public var manifestReference: ArtifactReference?

    public init(
        caseID: String,
        manifestPath: String,
        expectedOutcome: PDKCorpusExpectedOutcome,
        observedOutcome: PDKCorpusExpectedOutcome,
        passed: Bool,
        expectedFindingCodes: [String],
        observedFindingCodes: [String],
        missingExpectedFindingCodes: [String],
        standardViewResults: [PDKCorpusStandardViewResult] = [],
        ruleDeckResults: [PDKCorpusRuleDeckResult] = [],
        manifestReference: ArtifactReference? = nil
    ) {
        self.caseID = caseID
        self.manifestPath = manifestPath
        self.expectedOutcome = expectedOutcome
        self.observedOutcome = observedOutcome
        self.passed = passed
        self.expectedFindingCodes = expectedFindingCodes
        self.observedFindingCodes = observedFindingCodes
        self.missingExpectedFindingCodes = missingExpectedFindingCodes
        self.standardViewResults = standardViewResults
        self.ruleDeckResults = ruleDeckResults
        self.manifestReference = manifestReference
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caseID = try container.decode(String.self, forKey: .caseID)
        manifestPath = try container.decode(String.self, forKey: .manifestPath)
        expectedOutcome = try container.decode(PDKCorpusExpectedOutcome.self, forKey: .expectedOutcome)
        observedOutcome = try container.decode(PDKCorpusExpectedOutcome.self, forKey: .observedOutcome)
        passed = try container.decode(Bool.self, forKey: .passed)
        expectedFindingCodes = try container.decodeIfPresent([String].self, forKey: .expectedFindingCodes) ?? []
        observedFindingCodes = try container.decodeIfPresent([String].self, forKey: .observedFindingCodes) ?? []
        missingExpectedFindingCodes = try container.decodeIfPresent([String].self, forKey: .missingExpectedFindingCodes) ?? []
        standardViewResults = try container.decodeIfPresent([PDKCorpusStandardViewResult].self, forKey: .standardViewResults) ?? []
        ruleDeckResults = try container.decodeIfPresent([PDKCorpusRuleDeckResult].self, forKey: .ruleDeckResults) ?? []
        manifestReference = try container.decodeIfPresent(ArtifactReference.self, forKey: .manifestReference)
    }

    private enum CodingKeys: String, CodingKey {
        case caseID
        case manifestPath
        case expectedOutcome
        case observedOutcome
        case passed
        case expectedFindingCodes
        case observedFindingCodes
        case missingExpectedFindingCodes
        case standardViewResults
        case ruleDeckResults
        case manifestReference
    }
}
