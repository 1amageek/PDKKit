import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation

/// Caller-selected availability and per-operation limits; no root is inferred.
public struct PDKBoundedDiscoveryRoot: Sendable {
    public let rootURL: URL
    public let inventory: ArtifactDirectoryInventoryIntent
    public let sourceBudget: ArtifactAccessBudget
    internal let binding: String

    public init(rootURL: URL, inventory: ArtifactDirectoryInventoryIntent,
                sourceBudget: ArtifactAccessBudget) throws(PDKBoundedDiscoveryError) {
        guard rootURL.isFileURL, rootURL.baseURL == nil, rootURL.path.hasPrefix("/") else {
            throw .incomplete(progress: .init(completedRootCount: 0, observedCandidateCount: 0), failure: .invalidRootURL)
        }
        self.rootURL = rootURL; self.inventory = inventory; self.sourceBudget = sourceBudget
        binding = rootURL.absoluteString
    }
}
