import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKSourceCapture

struct PDKCapturedSourceMutation: PDKLocalSourceCapturing {
    enum Mutation: Sendable { case replace, remove }
    let file: URL
    let mutation: Mutation

    func capture(
        reference: ArtifactReference,
        at locator: ArtifactLocator,
        relativeTo root: URL?,
        budget: ArtifactAccessBudget
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        let captured = try await LocalPDKSourceCapturer().capture(
            reference: reference, at: locator, relativeTo: root, budget: budget
        )
        do {
            switch mutation {
            case .replace: try Data("invalid replacement".utf8).write(to: file, options: .atomic)
            case .remove: try FileManager.default.removeItem(at: file)
            }
        } catch { throw .invalidLocation(reason: "Test mutation failed: \(error)") }
        return captured
    }
}
