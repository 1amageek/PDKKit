/// A complete search over exactly the caller-supplied roots.
public struct PDKBoundedDiscoveryResult: Sendable {
    public let candidates: PDKBoundedCandidateCollection
    public let progress: PDKBoundedDiscoveryProgress
    internal init(candidates: PDKBoundedCandidateCollection, progress: PDKBoundedDiscoveryProgress) {
        self.candidates = candidates; self.progress = progress
    }
}
