import Foundation

public struct PDKCorpusCase: Sendable, Hashable, Codable {
    public var caseID: String
    public var manifestPath: String
    public var expectedOutcome: PDKCorpusExpectedOutcome
    public var expectedFindingCodes: [String]
    public var requiredAssetRoles: [PDKAssetRole]
    public var validateCrossViews: Bool
    public var standardViewChecks: [PDKCorpusStandardViewCheck]
    public var ruleDeckChecks: [PDKCorpusRuleDeckCheck]
    public var metadata: [String: String]

    public init(
        caseID: String,
        manifestPath: String,
        expectedOutcome: PDKCorpusExpectedOutcome,
        expectedFindingCodes: [String] = [],
        requiredAssetRoles: [PDKAssetRole] = [],
        validateCrossViews: Bool = true,
        standardViewChecks: [PDKCorpusStandardViewCheck] = [],
        ruleDeckChecks: [PDKCorpusRuleDeckCheck] = [],
        metadata: [String: String] = [:]
    ) {
        self.caseID = caseID
        self.manifestPath = manifestPath
        self.expectedOutcome = expectedOutcome
        self.expectedFindingCodes = Array(Set(expectedFindingCodes)).sorted()
        self.requiredAssetRoles = Array(Set(requiredAssetRoles)).sorted { $0.rawValue < $1.rawValue }
        self.validateCrossViews = validateCrossViews
        self.standardViewChecks = standardViewChecks.sorted {
            ($0.assetID, $0.format) < ($1.assetID, $1.format)
        }
        self.ruleDeckChecks = ruleDeckChecks.sorted { $0.assetID < $1.assetID }
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            caseID: try container.decode(String.self, forKey: .caseID),
            manifestPath: try container.decode(String.self, forKey: .manifestPath),
            expectedOutcome: try container.decode(PDKCorpusExpectedOutcome.self, forKey: .expectedOutcome),
            expectedFindingCodes: try container.decode([String].self, forKey: .expectedFindingCodes),
            requiredAssetRoles: try container.decode([PDKAssetRole].self, forKey: .requiredAssetRoles),
            validateCrossViews: try container.decode(Bool.self, forKey: .validateCrossViews),
            standardViewChecks: try container.decode([PDKCorpusStandardViewCheck].self, forKey: .standardViewChecks),
            ruleDeckChecks: try container.decode([PDKCorpusRuleDeckCheck].self, forKey: .ruleDeckChecks),
            metadata: try container.decode([String: String].self, forKey: .metadata)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case caseID
        case manifestPath
        case expectedOutcome
        case expectedFindingCodes
        case requiredAssetRoles
        case validateCrossViews
        case standardViewChecks
        case ruleDeckChecks
        case metadata
    }
}
