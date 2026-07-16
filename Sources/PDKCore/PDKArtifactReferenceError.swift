import Foundation

public enum PDKArtifactReferenceError: Error, Sendable, Equatable, LocalizedError {
    case invalidByteCount(path: String)
    case invalidLocation(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidByteCount(let path):
            "PDK artifact has an invalid byte count: \(path)"
        case .invalidLocation(let path, let reason):
            "PDK artifact has an invalid location \(path): \(reason)"
        }
    }
}
