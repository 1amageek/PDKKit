import Foundation

public enum PDKReferenceError: Error, Sendable, Equatable, LocalizedError {
    case emptyProcessID
    case emptyVersion
    case malformedManifestDigest
    case invalidManifestDescriptor
    case locatorDescriptorMismatch
    case unsupportedSchemaVersion(Int)
    case obsoleteIdentityField(String)
    case manifestByteCountOverflow

    public var errorDescription: String? {
        switch self {
        case .emptyProcessID: "PDK process ID must not be empty."
        case .emptyVersion: "PDK version must not be empty."
        case .malformedManifestDigest: "PDK manifest must use SHA-256."
        case .invalidManifestDescriptor: "PDK manifest must be technology JSON."
        case .locatorDescriptorMismatch: "PDK locator must describe the supplied content reference."
        case .unsupportedSchemaVersion(let version): "Unsupported PDK identity schema version: \(version)."
        case .obsoleteIdentityField(let field): "Obsolete duplicate PDK identity field: \(field)."
        case .manifestByteCountOverflow: "PDK manifest byte count exceeds the supported boundary."
        }
    }
}
