public struct PDKProfileSourceContext: Sendable, Equatable {
    public let sourceKey: String
    public let cornerID: String?
    public let selectedSection: String?
    public let preprocessingIdentity: String
    public init(sourceKey: String, selectedSection: String?, preprocessingIdentity: String, cornerID: String? = nil) {
        self.cornerID = cornerID
        self.sourceKey = sourceKey; self.selectedSection = selectedSection
        self.preprocessingIdentity = preprocessingIdentity
    }
}
