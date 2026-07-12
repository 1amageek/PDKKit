import Foundation
import XcircuitePackage

public struct PDKManifestReferenceBuilder: Sendable {
    private let digestor: any PDKDigesting

    public init(digestor: any PDKDigesting = SHA256PDKDigestor()) {
        self.digestor = digestor
    }

    public func makeReference(for url: URL) throws -> PDKReference {
        let data = try Data(contentsOf: url)
        let decoded = try PDKManifestCodec.decode(data: data)
        let digest = try digestor.digest(data: data)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value
        let manifestReference = XcircuiteFileReference(
            artifactID: "pdk-manifest",
            path: url.path,
            kind: .technology,
            format: .json,
            sha256: digest,
            byteCount: byteCount
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
