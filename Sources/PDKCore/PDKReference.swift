import CircuiteFoundation
import Foundation

public struct PDKReference: Sendable, Hashable, Codable {
    public var manifest: ArtifactReference
    public var processID: String
    public var version: String
    public var digest: String

    public init(
        manifest: ArtifactReference,
        processID: String,
        version: String,
        digest: String
    ) {
        self.manifest = manifest
        self.processID = processID
        self.version = version
        self.digest = digest
    }

    public func validate() throws {
        guard !processID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PDKReferenceError.emptyProcessID
        }
        guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PDKReferenceError.emptyVersion
        }
        guard !digest.isEmpty else {
            throw PDKReferenceError.emptyDigest
        }
        let pdkDigest: ContentDigest
        do {
            pdkDigest = try ContentDigest(
                algorithm: .sha256,
                hexadecimalValue: digest
            )
        } catch {
            throw PDKReferenceError.malformedDigest
        }
        let manifestDigest = manifest.sha256
        let manifestContentDigest: ContentDigest
        do {
            manifestContentDigest = try ContentDigest(
                algorithm: .sha256,
                hexadecimalValue: manifestDigest
            )
        } catch {
            throw PDKReferenceError.malformedManifestDigest
        }
        if manifestContentDigest != pdkDigest {
            throw PDKReferenceError.manifestDigestMismatch(
                expected: pdkDigest.hexadecimalValue,
                actual: manifestDigest
            )
        }
    }

    /// Returns the manifest after validating its identity against the PDK digest.
    public func validatedManifest() throws -> ArtifactReference {
        try validate()
        return manifest
    }
}
