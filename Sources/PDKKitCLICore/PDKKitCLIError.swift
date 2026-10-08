import Foundation
import PDKDiscovery

public enum PDKKitCLIError: Error, Sendable, Equatable {
    case invalidArguments(String)
    case unreadableFile(path: String, reason: String)
    case invalidJSON(path: String, reason: String)
    case internalError(String)
    case manifestLoading(PDKManifestLoadingError)

    public var code: String {
        switch self {
        case .invalidArguments: "pdkkit.cli.invalid-arguments"
        case .unreadableFile: "pdkkit.cli.unreadable-file"
        case .invalidJSON: "pdkkit.cli.invalid-json"
        case .internalError: "pdkkit.cli.internal-error"
        case .manifestLoading(let error):
            if error.isCancellation { "pdkkit.cli.cancelled" }
            else {
                switch error {
                case .manifest: "pdkkit.cli.invalid-json"
                case .discovery: "pdkkit.cli.unreadable-file"
                default: "pdkkit.cli.manifest-load-failed"
                }
            }
        }
    }

    public var message: String {
        switch self {
        case .invalidArguments(let details): details
        case .unreadableFile(let path, let reason): "Cannot read file at \(path): \(reason)"
        case .invalidJSON(let path, let reason): "File at \(path) does not decode as the expected JSON model: \(reason)"
        case .internalError(let details): "Internal CLI failure: \(details)"
        case .manifestLoading(let error): "Manifest loading failed: \(error)"
        }
    }
}
