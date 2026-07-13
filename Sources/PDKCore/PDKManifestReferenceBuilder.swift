import CircuiteFoundation
import Foundation
import XcircuitePackage

public struct PDKManifestReferenceBuilder: Sendable {
    private let digester: any ContentDigesting

    public init(digester: any ContentDigesting = SHA256ContentDigester()) {
        self.digester = digester
    }

    public func makeReference(for url: URL) throws -> PDKReference {
        let data = try Data(contentsOf: url)
        let decoded = try PDKManifestCodec.decode(data: data)
        let location = try ArtifactLocation(fileURL: url)
        let artifactLocator = ArtifactLocator(
            location: location,
            kind: .technology,
            format: .json
        )
        let foundationReference = try LocalArtifactReferencer(digester: digester).reference(
            artifactLocator
        )
        guard foundationReference.byteCount <= UInt64(Int64.max) else {
            throw PDKReferenceError.manifestByteCountOverflow
        }
        let manifestURL = try location.resolvedFileURL()
        let digest = foundationReference.digest.hexadecimalValue
        let manifestReference = XcircuiteFileReference(
            artifactID: "pdk-manifest",
            path: manifestURL.path,
            kind: .technology,
            format: .json,
            sha256: digest,
            byteCount: Int64(foundationReference.byteCount)
        )
        let reference = PDKReference(
            manifest: manifestReference,
            processID: decoded.manifest.processID,
            version: decoded.manifest.version,
            digest: digest
        )
        try reference.validate()
        return reference
    }
}
