import Foundation
import XcircuitePackage

public struct LocalPDKAssetResolver: PDKAssetResolving {
    private let digestor: any PDKDigesting

    public init(digestor: any PDKDigesting = SHA256PDKDigestor()) {
        self.digestor = digestor
    }

    public func resolve(
        _ asset: PDKAssetReference,
        relativeTo manifestURL: URL
    ) throws -> PDKResolvedAsset {
        guard !asset.path.isEmpty else {
            throw PDKAssetResolutionError.emptyPath(assetID: asset.assetID)
        }
        let rootURL = manifestURL.deletingLastPathComponent().standardizedFileURL
        let assetURL = URL(filePath: asset.path, relativeTo: rootURL).standardizedFileURL
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard assetURL.path == rootURL.path || assetURL.path.hasPrefix(rootPath) else {
            throw PDKAssetResolutionError.outsideManifestRoot(assetID: asset.assetID, path: asset.path)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: assetURL.path, isDirectory: &isDirectory) else {
            throw PDKAssetResolutionError.missingFile(assetID: asset.assetID, path: assetURL.path)
        }
        guard !isDirectory.boolValue else {
            throw PDKAssetResolutionError.notRegularFile(assetID: asset.assetID, path: assetURL.path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: assetURL)
        } catch {
            throw PDKAssetResolutionError.unreadableFile(
                assetID: asset.assetID,
                path: assetURL.path,
                reason: error.localizedDescription
            )
        }
        let digest = try digestor.digest(data: data)
        let reference = XcircuiteFileReference(
            artifactID: asset.assetID,
            path: assetURL.path,
            kind: asset.kind,
            format: asset.format,
            sha256: digest,
            byteCount: Int64(data.count)
        )
        return PDKResolvedAsset(
            assetID: asset.assetID,
            path: assetURL.path,
            reference: reference,
            computedSHA256: digest,
            computedByteCount: Int64(data.count)
        )
    }
}
