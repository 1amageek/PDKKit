import Foundation
import PDKCore

struct MutatingViewAssetResolver: PDKAssetResolving {
    func resolve(_ asset: PDKAssetReference, relativeTo manifestURL: URL) throws -> PDKResolvedAsset {
        let resolved = try LocalPDKAssetResolver().resolve(asset, relativeTo: manifestURL)
        if asset.assetID == "cells" {
            let url = URL(filePath: resolved.path)
            let original = try String(contentsOf: url, encoding: .utf8)
            let changed = original.replacingOccurrences(of: "PITCH 0.2", with: "PITCH 0.3")
            guard original.utf8.count == changed.utf8.count, original != changed else {
                throw CocoaError(.fileWriteUnknown)
            }
            try changed.write(to: url, atomically: true, encoding: .utf8)
        }
        return resolved
    }
}
