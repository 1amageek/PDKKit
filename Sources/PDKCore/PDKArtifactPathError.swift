import Foundation

public enum PDKArtifactPathError: Error, Sendable, Equatable, LocalizedError {
    case emptyPath
    case baseDirectoryNotAbsolute(String)
    case pathEscapesBaseDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPath:
            "PDK artifact path must not be empty."
        case .baseDirectoryNotAbsolute(let path):
            "PDK artifact base directory must be absolute: \(path)."
        case .pathEscapesBaseDirectory(let path):
            "PDK artifact path escapes its base directory: \(path)."
        }
    }
}
