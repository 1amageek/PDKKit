import Foundation

public struct PDKCorpusRuleDeckCheck: Sendable, Hashable, Codable {
    public var assetID: String
    public var expectedOutcome: PDKCorpusExpectedOutcome
    public var expectedFindingCodes: [String]

    public init(
        assetID: String,
        expectedOutcome: PDKCorpusExpectedOutcome = .valid,
        expectedFindingCodes: [String] = []
    ) {
        self.assetID = assetID
        self.expectedOutcome = expectedOutcome
        self.expectedFindingCodes = Array(Set(expectedFindingCodes)).sorted()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            assetID: try container.decode(String.self, forKey: .assetID),
            expectedOutcome: try container.decodeIfPresent(PDKCorpusExpectedOutcome.self, forKey: .expectedOutcome) ?? .valid,
            expectedFindingCodes: try container.decodeIfPresent([String].self, forKey: .expectedFindingCodes) ?? []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case assetID
        case expectedOutcome
        case expectedFindingCodes
    }
}
