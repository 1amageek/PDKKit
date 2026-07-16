import CircuiteFoundation
import Foundation
import CircuiteFoundation

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
        let foundationReference = try PDKFoundationArtifactBridge.artifactReference(
            assetID: "pdk-manifest",
            path: url,
            kind: artifactLocator.kind,
            format: artifactLocator.format,
            digest: materializedReference.digest,
            byteCount: materializedReference.byteCount
        )
        guard foundationReference.byteCount <= UInt64(Int64.max) else {
            throw PDKReferenceError.manifestByteCountOverflow
        }
        let digest = foundationReference.digest.hexadecimalValue
        let reference = PDKReference(
            manifest: foundationReference,
            processID: manifest.processID,
            version: manifest.version,
            digest: digest
        )
        try reference.validate()
        return reference
    }
}
