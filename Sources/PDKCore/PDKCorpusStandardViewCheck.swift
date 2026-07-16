import Foundation

public struct PDKCorpusStandardViewCheck: Sendable, Hashable, Codable {
    public var assetID: String
    public var format: String
    public var expectedOutcome: PDKCorpusExpectedOutcome
    public var expectedFindingCodes: [String]

    public init(
        assetID: String,
        format: String,
        expectedOutcome: PDKCorpusExpectedOutcome = .valid,
        expectedFindingCodes: [String] = []
    ) {
        self.assetID = assetID
        self.format = format.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.expectedOutcome = expectedOutcome
        self.expectedFindingCodes = Array(Set(expectedFindingCodes)).sorted()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            assetID: try container.decode(String.self, forKey: .assetID),
            format: try container.decode(String.self, forKey: .format),
            expectedOutcome: try container.decode(PDKCorpusExpectedOutcome.self, forKey: .expectedOutcome),
            expectedFindingCodes: try container.decode([String].self, forKey: .expectedFindingCodes)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case assetID
        case format
        case expectedOutcome
        case expectedFindingCodes
    }
}
