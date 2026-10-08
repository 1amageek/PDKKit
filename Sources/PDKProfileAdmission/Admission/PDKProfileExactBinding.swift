import CircuiteFoundation

public struct PDKProfileExactBinding: Sendable {
    public let reference: ArtifactReference
    public let rootID: ArtifactRootID
    public let relativePath: ArtifactRelativePath
    public let budget: ArtifactAccessBudget
    public init(reference: ArtifactReference, rootID: ArtifactRootID,
                relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget) {
        self.reference = reference; self.rootID = rootID; self.relativePath = relativePath; self.budget = budget
    }
}
