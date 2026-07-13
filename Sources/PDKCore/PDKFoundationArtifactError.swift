import Foundation

public enum PDKFoundationArtifactError: Error, Sendable, Equatable, LocalizedError {
    case missingDigest(path: String)
    case malformedDigest(path: String, reason: String)
    case missingByteCount(path: String)
    case invalidByteCount(path: String)
    case invalidLocation(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .missingDigest(let path):
            "PDK artifact has no content digest: \(path)"
        case .malformedDigest(let path, let reason):
            "PDK artifact has an invalid content digest at \(path): \(reason)"
        case .missingByteCount(let path):
            "PDK artifact has no byte count: \(path)"
        case .invalidByteCount(let path):
            "PDK artifact has an invalid byte count: \(path)"
        case .invalidLocation(let path, let reason):
            "PDK artifact has an invalid location \(path): \(reason)"
        }
    }
}
