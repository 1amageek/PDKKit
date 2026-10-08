import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKSourceCapture

struct BoundMutatingSourceCapturer: PDKLocalSourceCapturing {
    let fileName: String
    let mutation: BoundCaptureMutation

    func capture(
        reference: ArtifactReference,
        at locator: ArtifactLocator,
        relativeTo root: URL?,
        budget: ArtifactAccessBudget
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        let captured = try await LocalPDKSourceCapturer().capture(
            reference: reference, at: locator, relativeTo: root, budget: budget
        )
        let url: URL
        do { url = try locator.location.resolvedFileURL(relativeTo: root) }
        catch { throw .invalidLocation(reason: String(describing: error)) }
        guard url.lastPathComponent == fileName else { return captured }
        switch mutation {
        case .refuse(let error): throw error
        case .replace, .remove:
            do {
                if case .replace = mutation {
                    try Data("substituted invalid source".utf8).write(to: url, options: .atomic)
                } else {
                    try FileManager.default.removeItem(at: url)
                }
            } catch { throw .invalidLocation(reason: String(describing: error)) }
        }
        return captured
    }
}
