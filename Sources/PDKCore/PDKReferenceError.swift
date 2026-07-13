import Foundation

public enum PDKReferenceError: Error, Sendable, Equatable, LocalizedError {
    case emptyProcessID
    case emptyVersion
    case emptyDigest
    case malformedDigest
    case missingManifestDigest
    case malformedManifestDigest
    case missingManifestByteCount
    case invalidManifestByteCount
    case manifestByteCountOverflow
    case manifestDigestMismatch(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .emptyProcessID:
            "PDK process ID must not be empty."
        case .emptyVersion:
            "PDK version must not be empty."
        case .emptyDigest:
            "PDK digest must not be empty."
        case .malformedDigest:
            "PDK digest must be a valid SHA-256 value."
        case .missingManifestDigest:
            "PDK manifest reference must carry a SHA-256 digest."
        case .malformedManifestDigest:
            "PDK manifest digest must be a valid SHA-256 value."
        case .missingManifestByteCount:
            "PDK manifest reference must carry a byte count."
        case .invalidManifestByteCount:
            "PDK manifest byte count must be non-negative."
        case .manifestByteCountOverflow:
            "PDK manifest byte count cannot be represented by the artifact contract."
        case .manifestDigestMismatch(let expected, let actual):
            "PDK manifest digest mismatch; expected \(expected), received \(actual)."
        }
    }
}
