import CircuiteFoundation

/// Explicit approved logical routes and backing availability, without an expected digest.
public struct PDKSpiceCandidateBinding: Sendable {
    public let sourceKey: String
    public let assetID: String?
    public let logicalRoutes: [String]
    public let rootID: ArtifactRootID
    public let relativePath: ArtifactRelativePath
    public let budget: ArtifactAccessBudget
    public let descriptor: ArtifactDescriptor
    public init(sourceKey: String, assetID: String?, logicalRoutes: [String], rootID: ArtifactRootID,
                relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget, descriptor: ArtifactDescriptor) {
        self.sourceKey = sourceKey; self.assetID = assetID; self.logicalRoutes = logicalRoutes
        self.rootID = rootID; self.relativePath = relativePath; self.budget = budget; self.descriptor = descriptor
    }
}
