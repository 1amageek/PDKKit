import CircuiteFoundation
import Foundation
import CircuiteFoundation

public struct LocalPDKAssetResolver: PDKAssetResolving {
    private let referencer: LocalArtifactReferencer

    public init(contentDigester: any ContentDigesting = SHA256ContentDigester()) {
        self.referencer = LocalArtifactReferencer(digester: contentDigester)
    }

    public func resolve(
        _ asset: PDKAssetReference,
        relativeTo manifestURL: URL
    ) throws -> PDKResolvedAsset {
        guard !asset.path.isEmpty else {
            throw PDKAssetResolutionError.emptyPath(assetID: asset.assetID)
        }
        let rootURL = manifestURL.deletingLastPathComponent().standardizedFileURL
        let locator: ArtifactLocator
        do {
            locator = try asset.artifactLocator()
        } catch {
            throw PDKAssetResolutionError.invalidPath(
                assetID: asset.assetID,
                path: asset.path,
                reason: error.localizedDescription
            )
        }

        let foundationReference: ArtifactReference
        do {
            foundationReference = try referencer.reference(
                locator,
                relativeTo: rootURL
            )
        } catch let error as ArtifactReferenceError {
            switch error {
            case .fileNotFound(let url):
                throw PDKAssetResolutionError.missingFile(assetID: asset.assetID, path: url.path)
            case .notRegularFile(let url):
                throw PDKAssetResolutionError.notRegularFile(assetID: asset.assetID, path: url.path)
            case .metadataUnavailable(let url, let reason):
                throw PDKAssetResolutionError.unreadableFile(
                    assetID: asset.assetID,
                    path: url.path,
                    reason: reason
                )
            case .byteCountOverflow(let url):
                throw PDKAssetResolutionError.byteCountOverflow(assetID: asset.assetID, path: url.path)
            case .changedDuringReference(let url):
                throw PDKAssetResolutionError.changedDuringReference(
                    assetID: asset.assetID,
                    path: url.path
                )
            }
        } catch let error as ArtifactLocationError {
            switch error {
            case .outsideWorkspaceRoot(let url):
                throw PDKAssetResolutionError.outsideManifestRoot(
                    assetID: asset.assetID,
                    path: url.path
                )
            default:
                throw PDKAssetResolutionError.invalidPath(
                    assetID: asset.assetID,
                    path: asset.path,
                    reason: error.localizedDescription
                )
            }
        } catch {
            throw PDKAssetResolutionError.unreadableFile(
                assetID: asset.assetID,
                path: rootURL.appending(path: asset.path).path,
                reason: error.localizedDescription
            )
        }

        guard foundationReference.byteCount <= UInt64(Int64.max) else {
            throw PDKAssetResolutionError.byteCountOverflow(
                assetID: asset.assetID,
                path: foundationReference.locator.location.value
            )
        }
        let assetURL = try foundationReference.locator.location.resolvedFileURL(relativeTo: rootURL)
        let reference = try ArtifactReference(
            id: ArtifactID(rawValue: asset.assetID),
            locator: ArtifactLocator(
                location: ArtifactLocation(fileURL: assetURL),
                role: foundationReference.locator.role,
                kind: foundationReference.locator.kind,
                format: foundationReference.locator.format
            ),
            digest: foundationReference.digest,
            byteCount: foundationReference.byteCount
        )
        return PDKResolvedAsset(
            assetID: asset.assetID,
            path: assetURL.path,
            reference: reference,
            computedSHA256: foundationReference.digest.hexadecimalValue,
            computedByteCount: Int64(foundationReference.byteCount)
        )
    }
}
