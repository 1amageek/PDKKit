import Foundation

public enum PDKOracleExpectationError: Error, Sendable, Equatable, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "Unsupported PDK oracle schema version: \(version)"
        case .invalid(let reason):
            "Invalid PDK oracle expectation: \(reason)"
        }
    }
}
