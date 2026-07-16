import Foundation
import CircuiteFoundation

public struct PDKResolvedAsset: Sendable, Hashable, Codable {
    public var assetID: String
    public var path: String
    public var reference: ArtifactReference
    public var computedSHA256: String
    public var computedByteCount: Int64

    public init(
        assetID: String,
        path: String,
        reference: ArtifactReference,
        computedSHA256: String,
        computedByteCount: Int64
    ) {
        self.assetID = assetID
        self.path = path
        self.reference = reference
        self.computedSHA256 = computedSHA256
        self.computedByteCount = computedByteCount
    }

    /// Builds the immutable artifact identity for this resolved asset.
    public func artifactReference() throws -> ArtifactReference {
        guard computedByteCount >= 0 else {
            throw PDKArtifactReferenceError.invalidByteCount(path: path)
        }
        let digest = try ContentDigest(
            algorithm: .sha256,
            hexadecimalValue: computedSHA256
        )
        return try PDKArtifactReferenceBuilder.artifactReference(
            assetID: assetID,
            path: URL(filePath: path),
            kind: reference.kind,
            format: reference.format,
            digest: digest,
            byteCount: UInt64(computedByteCount)
        )
    }
}
