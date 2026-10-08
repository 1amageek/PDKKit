public struct PDKProfileDependencyRequest: Sendable {
    public let parent: PDKProfileSourceInput
    public let statementByteOffset: UInt64
    public let statementOrdinal: UInt64
    public let directiveKind: String
    public let literalRoute: String
    public let selectedSection: String?
    public let preprocessingIdentity: String
    public init(parent: PDKProfileSourceInput, statementByteOffset: UInt64, statementOrdinal: UInt64,
                directiveKind: String, literalRoute: String, selectedSection: String?, preprocessingIdentity: String) {
        self.parent = parent; self.statementByteOffset = statementByteOffset; self.statementOrdinal = statementOrdinal
        self.directiveKind = directiveKind; self.literalRoute = literalRoute
        self.selectedSection = selectedSection; self.preprocessingIdentity = preprocessingIdentity
    }
}
