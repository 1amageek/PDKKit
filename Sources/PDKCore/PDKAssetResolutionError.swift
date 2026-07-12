import Foundation

public enum PDKAssetResolutionError: Error, Sendable, Equatable {
    case emptyPath(assetID: String)
    case missingFile(assetID: String, path: String)
    case notRegularFile(assetID: String, path: String)
    case outsideManifestRoot(assetID: String, path: String)
    case unreadableFile(assetID: String, path: String, reason: String)
}
