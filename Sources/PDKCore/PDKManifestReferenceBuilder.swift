import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
import Foundation

// FIXME(INCOMPLETE_IMPLEMENTATION): Metadata and digest are still read separately.
// Discovery, CLI and corpus call this path until the ManifestLoading migration.
// Do not claim consistent generation until metadata is decoded from captured bytes.
public struct PDKManifestReferenceBuilder: Sendable {
    private let digester: any ContentDigesting

    public init(digester: any ContentDigesting = SHA256ContentDigester()) {
        self.digester = digester
    }

    public func makeReference(for url: URL) throws -> PDKReference {
        let data = try Data(contentsOf: url)
        let manifest = try PDKManifestCodec.decode(data: data)
        let location = try ArtifactLocation(fileURL: url)
        let artifactLocator = ArtifactLocator(
            location: location,
            role: .input,
            kind: .technology,
            format: .json
        )
        let materializedReference = try LocalArtifactReferencer(digester: digester).reference(
            artifactLocator
        )
        let foundationReference = try PDKArtifactReferenceBuilder.artifactReference(
            kind: artifactLocator.kind,
            format: artifactLocator.format,
            digest: materializedReference.digest,
            byteCount: materializedReference.byteCount
        )
        guard foundationReference.byteCount <= UInt64(Int64.max) else {
            throw PDKReferenceError.manifestByteCountOverflow
        }
        let reference = try PDKReference(
            manifest: foundationReference,
            manifestLocator: artifactLocator,
            processID: manifest.processID,
            version: manifest.version
        )
        try reference.validate()
        return reference
    }
}
