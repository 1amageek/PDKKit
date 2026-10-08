/// No partial inventory is published after an incomplete search.
public enum PDKBoundedDiscoveryError: Error, Sendable, Equatable {
    case incomplete(progress: PDKBoundedDiscoveryProgress, failure: PDKBoundedDiscoveryFailure)
}
