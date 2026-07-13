import Foundation
import CircuiteFoundation
import XcircuitePackage

public struct PDKResolvedAsset: Sendable, Hashable, Codable {
    public var assetID: String
    public var path: String
    public var reference: XcircuiteFileReference
    public var computedSHA256: String
    public var computedByteCount: Int64

    public init(
        assetID: String,
        path: String,
        reference: XcircuiteFileReference,
        computedSHA256: String,
        computedByteCount: Int64
    ) {
        self.assetID = assetID
        self.path = path
        self.reference = reference
        self.computedSHA256 = computedSHA256
        self.computedByteCount = computedByteCount
    }

    /// Returns the immutable Foundation identity for a resolved asset.
    public func foundationArtifactReference() throws -> ArtifactReference {
        guard computedByteCount >= 0 else {
            throw PDKFoundationArtifactError.invalidByteCount(path: path)
        }
        let digest = try ContentDigest(
            algorithm: .sha256,
            hexadecimalValue: computedSHA256
        )
        return try PDKFoundationArtifactBridge.artifactReference(
            assetID: assetID,
            path: URL(filePath: path),
            kind: reference.kind,
            format: reference.format,
            digest: digest,
            byteCount: UInt64(computedByteCount)
        )
    }
}
