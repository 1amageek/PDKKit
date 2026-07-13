import Foundation

public enum PDKExternalInspectionError: Error, Sendable, Equatable, LocalizedError {
    case invalidJSON(String)
    case schemaVersionMismatch(expected: Int, actual: Int)
    case runIDMismatch(expected: String, actual: String)
    case assetIDMismatch(expected: String, actual: String)
    case standardViewFormatMismatch(expected: PDKStandardViewFormat, actual: PDKStandardViewFormat)
    case pdkDigestMismatch(expected: String, actual: String)
    case completedPayloadInvalid(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let reason):
            "External inspection result is not valid JSON: " + reason
        case .schemaVersionMismatch(let expected, let actual):
            "External inspection result schema version \(actual) does not match expected version \(expected)."
        case .runIDMismatch(let expected, let actual):
            "External inspection result run ID \(actual) does not match expected run ID \(expected)."
        case .assetIDMismatch(let expected, let actual):
            "External inspection result asset ID \(actual) does not match expected asset ID \(expected)."
        case .standardViewFormatMismatch(let expected, let actual):
            "External standard-view format \(actual.rawValue) does not match expected format \(expected.rawValue)."
        case .pdkDigestMismatch(let expected, let actual):
            "External rule-deck result PDK digest \(actual) does not match expected digest \(expected)."
        case .completedPayloadInvalid(let reason):
            "External inspection returned a completed result with invalid payload: " + reason
        }
    }
}
