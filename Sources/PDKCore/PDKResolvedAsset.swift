import Foundation
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
}
