/// Incomplete-search evidence; counts do not imply profile admission.
public struct PDKBoundedDiscoveryProgress: Sendable, Equatable {
    public let completedRootCount: Int
    public let observedCandidateCount: Int
    internal init(completedRootCount: Int, observedCandidateCount: Int) {
        self.completedRootCount = completedRootCount
        self.observedCandidateCount = observedCandidateCount
    }
}
