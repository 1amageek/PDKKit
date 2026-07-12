import Foundation

public protocol PDKAssetResolving: Sendable {
    func resolve(
        _ asset: PDKAssetReference,
        relativeTo manifestURL: URL
    ) throws -> PDKResolvedAsset
}
