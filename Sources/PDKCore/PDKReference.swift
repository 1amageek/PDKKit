import CircuiteFoundation
import Foundation
import XcircuitePackage

public struct PDKReference: Sendable, Hashable, Codable {
    public var manifest: XcircuiteFileReference
    public var processID: String
    public var version: String
    public var digest: String

    public init(
        manifest: XcircuiteFileReference,
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
        guard let manifestDigest = manifest.sha256 else {
            throw PDKReferenceError.missingManifestDigest
        }
        let manifestContentDigest: ContentDigest
        do {
            manifestContentDigest = try ContentDigest(
                algorithm: .sha256,
                hexadecimalValue: manifestDigest
            )
        } catch {
            throw PDKReferenceError.malformedManifestDigest
        }
        guard let manifestByteCount = manifest.byteCount else {
            throw PDKReferenceError.missingManifestByteCount
        }
        guard manifestByteCount >= 0 else {
            throw PDKReferenceError.invalidManifestByteCount
        }
        if manifestContentDigest != pdkDigest {
            throw PDKReferenceError.manifestDigestMismatch(
                expected: pdkDigest.hexadecimalValue,
                actual: manifestDigest
            )
        }
    }

    /// Projects the manifest identity into the canonical Foundation artifact model.
    public func foundationManifestReference() throws -> ArtifactReference {
        try validate()
        guard let hexadecimalValue = manifest.sha256,
              let byteCount = manifest.byteCount,
              byteCount >= 0 else {
            throw PDKReferenceError.invalidManifestByteCount
        }

        let location: ArtifactLocation
        if manifest.path.hasPrefix("/") {
            location = try ArtifactLocation(fileURL: URL(filePath: manifest.path))
        } else {
            location = try ArtifactLocation(workspaceRelativePath: manifest.path)
        }
        return ArtifactReference(
            id: try ArtifactID(rawValue: manifest.artifactID ?? "pdk-manifest"),
            locator: ArtifactLocator(
                location: location,
                kind: try ArtifactKind(rawValue: "pdk.\(manifest.kind.rawValue.lowercased())"),
                format: try PDKFoundationArtifactBridge.artifactFormat(for: manifest.format)
            ),
            digest: try ContentDigest(
                algorithm: .sha256,
                hexadecimalValue: hexadecimalValue
            ),
            byteCount: UInt64(byteCount)
        )
    }
}
