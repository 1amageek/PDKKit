import Foundation

public enum PDKAssetResolutionError: Error, Sendable, Equatable, LocalizedError {
    case emptyPath(assetID: String)
    case invalidPath(assetID: String, path: String, reason: String)
    case missingFile(assetID: String, path: String)
    case notRegularFile(assetID: String, path: String)
    case outsideManifestRoot(assetID: String, path: String)
    case byteCountOverflow(assetID: String, path: String)
    case changedDuringReference(assetID: String, path: String)
    case unreadableFile(assetID: String, path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .emptyPath(let assetID):
            "PDK asset path is empty: \(assetID)"
        case .invalidPath(let assetID, let path, let reason):
            "PDK asset path is invalid for \(assetID) (\(path)): \(reason)"
        case .missingFile(let assetID, let path):
            "PDK asset file is missing for \(assetID): \(path)"
        case .notRegularFile(let assetID, let path):
            "PDK asset is not a regular file for \(assetID): \(path)"
        case .outsideManifestRoot(let assetID, let path):
            "PDK asset escapes its manifest root for \(assetID): \(path)"
        case .byteCountOverflow(let assetID, let path):
            "PDK asset byte count cannot be represented for \(assetID): \(path)"
        case .changedDuringReference(let assetID, let path):
            "PDK asset changed while it was being referenced for \(assetID): \(path)"
        case .unreadableFile(let assetID, let path, let reason):
            "PDK asset could not be read for \(assetID) at \(path): \(reason)"
        }
    }
}
