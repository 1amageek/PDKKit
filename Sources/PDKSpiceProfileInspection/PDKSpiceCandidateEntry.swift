/// One explicitly selected root parse context, in proposal traversal order.
public struct PDKSpiceCandidateEntry: Sendable {
    public let sourceKey: String
    public let logicalRoute: String
    public let selectedSection: String?
    public init(sourceKey: String, logicalRoute: String, selectedSection: String? = nil) {
        self.sourceKey = sourceKey; self.logicalRoute = logicalRoute; self.selectedSection = selectedSection
    }
}
