import Foundation

public enum PDKStandardViewTextParseError: Error, Sendable, Equatable, LocalizedError {
    case invalidEncoding
    case malformed(format: PDKStandardViewFormat, line: Int, reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            "Text standard-view input is not valid UTF-8."
        case .malformed(let format, let line, let reason):
            "Malformed \(format.rawValue) input at line \(line): \(reason)"
        }
    }
}
