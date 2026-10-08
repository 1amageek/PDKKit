import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation

public struct PDKReference: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2
    public let manifest: ArtifactReference
    public let manifestLocator: ArtifactLocator
    public let processID: String
    public let version: String
    public var digest: String { manifest.digest.hexadecimalValue }

    public init(
        manifest: ArtifactReference,
        manifestLocator: ArtifactLocator,
        processID: String,
        version: String
    ) throws(PDKReferenceError) {
        self.manifest = manifest
        self.manifestLocator = manifestLocator
        self.processID = processID
        self.version = version
        try validate()
    }

    public func validate() throws(PDKReferenceError) {
        guard !processID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw .emptyProcessID }
        guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw .emptyVersion }
        try Self.validateManifest(reference: manifest, at: manifestLocator)
    }

    public static func validateManifest(reference manifest: ArtifactReference, at manifestLocator: ArtifactLocator) throws(PDKReferenceError) {
        guard manifest.digest.algorithm == .sha256 else { throw .malformedManifestDigest }
        guard manifest.format == .json,
              PDKIdentityDescriptorPolicy.normalizedKind(manifest.kind) == "pdk.technology" else {
            throw .invalidManifestDescriptor
        }
        guard PDKIdentityDescriptorPolicy.matches(manifestLocator, reference: manifest) else {
            throw .locatorDescriptorMismatch
        }
    }

    public func validatedManifest() throws(PDKReferenceError) -> ArtifactReference {
        try validate()
        return manifest
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, manifest, manifestLocator, processID, version, digest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try container.decode(Int.self, forKey: .schemaVersion)
        guard schema == Self.currentSchemaVersion else { throw PDKReferenceError.unsupportedSchemaVersion(schema) }
        guard !container.contains(.digest) else { throw PDKReferenceError.obsoleteIdentityField("digest") }
        try self.init(
            manifest: container.decode(ArtifactReference.self, forKey: .manifest),
            manifestLocator: container.decode(ArtifactLocator.self, forKey: .manifestLocator),
            processID: container.decode(String.self, forKey: .processID),
            version: container.decode(String.self, forKey: .version)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(manifest, forKey: .manifest)
        try container.encode(manifestLocator, forKey: .manifestLocator)
        try container.encode(processID, forKey: .processID)
        try container.encode(version, forKey: .version)
    }
}
