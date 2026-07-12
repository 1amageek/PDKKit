import Foundation

public enum PDKManifestError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidField(field: String, reason: String)
    case invalidDigest(String)
    case invalidAssetPath(String)
}
