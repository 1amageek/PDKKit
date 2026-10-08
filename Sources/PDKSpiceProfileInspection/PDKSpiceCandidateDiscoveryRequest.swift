import PDKProfileAdmission

public struct PDKSpiceCandidateDiscoveryRequest: Sendable {
    public let roots: [PDKProfileAuthorizedRoot]
    public let sources: [PDKSpiceCandidateBinding]
    public let entries: [PDKSpiceCandidateEntry]
    public let orderedSearchRoutes: [String]
    public init(roots: [PDKProfileAuthorizedRoot], sources: [PDKSpiceCandidateBinding],
                entries: [PDKSpiceCandidateEntry], orderedSearchRoutes: [String]) {
        self.roots = roots; self.sources = sources; self.entries = entries; self.orderedSearchRoutes = orderedSearchRoutes
    }
}
