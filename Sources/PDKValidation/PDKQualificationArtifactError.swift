import Foundation

public enum PDKQualificationArtifactError: Error, Sendable, Equatable, LocalizedError {
    case unreadable(path: String, reason: String)
    case integrity(path: String, reason: String)
    case decode(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let path, let reason):
            "Qualification artifact is unreadable at \(path): \(reason)"
        case .integrity(let path, let reason):
            "Qualification artifact integrity failed at \(path): \(reason)"
        case .decode(let path, let reason):
            "Qualification artifact could not be decoded at \(path): \(reason)"
        }
    }
}
