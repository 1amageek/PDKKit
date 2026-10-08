import Foundation
import PDKCore

struct CancellingPDKAssetResolver: PDKAssetResolving {
    func resolve(_ asset: PDKAssetReference, relativeTo manifestURL: URL) throws -> PDKResolvedAsset {
        throw CancellationError()
    }
}
