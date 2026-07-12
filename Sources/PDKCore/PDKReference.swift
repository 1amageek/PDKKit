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
        let isSHA256 = digest.count == 64 && digest.allSatisfy { $0.isHexDigit }
        guard isSHA256 else {
            throw PDKReferenceError.malformedDigest
        }
    }
}
