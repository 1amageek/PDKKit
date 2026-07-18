public enum PDKOperation: String, Sendable, Hashable, Codable, CaseIterable {
    case discovery = "pdk.discover"
    case validation = "pdk.validate"
    case corpusValidation = "pdk.validate-corpus"
    case standardViewInspection = "pdk.inspect-standard-view"
    case ruleDeckInspection = "pdk.inspect-rule-deck"
    case oracleComparison = "pdk.compare-oracle"
}
