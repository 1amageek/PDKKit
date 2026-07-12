import Foundation

public enum PDKValidationError: Error, Sendable, Equatable {
    case manifestUnreadable(path: String, reason: String)
    case manifestDecodeFailed(path: String, reason: String)
    case unsupportedInput(String)
}
