import Foundation

public enum PDKKitCLIError: Error, Sendable, Equatable {
    case invalidArguments(String)
    case unreadableFile(path: String, reason: String)
    case invalidJSON(path: String, reason: String)
    case internalError(String)

    public var code: String {
        switch self {
        case .invalidArguments: "pdkkit.cli.invalid-arguments"
        case .unreadableFile: "pdkkit.cli.unreadable-file"
        case .invalidJSON: "pdkkit.cli.invalid-json"
        case .internalError: "pdkkit.cli.internal-error"
        }
    }

    public var message: String {
        switch self {
        case .invalidArguments(let details): details
        case .unreadableFile(let path, let reason): "Cannot read file at \(path): \(reason)"
        case .invalidJSON(let path, let reason): "File at \(path) does not decode as the expected JSON model: \(reason)"
        case .internalError(let details): "Internal CLI failure: \(details)"
        }
    }
}
