import Foundation

public enum PDKCorpusSuiteCodecError: Error, Sendable, Equatable, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidJSON(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "PDK corpus suite schema version \(version) is not supported."
        case .invalidJSON(let reason):
            "PDK corpus suite JSON is invalid: \(reason)"
        }
    }
}
