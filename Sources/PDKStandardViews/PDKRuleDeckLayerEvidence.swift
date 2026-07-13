import Foundation

public struct PDKRuleDeckLayerEvidence: Sendable, Hashable, Codable {
    public var layerID: String
    public var matchedTokens: [String]
    public var statementIndices: [Int]

    public init(
        layerID: String,
        matchedTokens: [String] = [],
        statementIndices: [Int] = []
    ) {
        self.layerID = layerID
        self.matchedTokens = matchedTokens
        self.statementIndices = statementIndices
    }
}
