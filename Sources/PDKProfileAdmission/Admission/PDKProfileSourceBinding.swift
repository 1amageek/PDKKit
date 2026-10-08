import CircuiteFoundation

public struct PDKProfileSourceBinding: Sendable {
    public let sourceKey: String
    public let logicalRoute: String
    public let rootID: ArtifactRootID
    public let relativePath: ArtifactRelativePath
    public let budget: ArtifactAccessBudget
    public init(sourceKey: String, logicalRoute: String, rootID: ArtifactRootID,
                relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget) {
        self.sourceKey = sourceKey; self.logicalRoute = logicalRoute
        self.rootID = rootID; self.relativePath = relativePath; self.budget = budget
    }
}
