import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKSourceCapture

struct PDKFailingSourceCapturer: PDKLocalSourceCapturing {
    let failure: PDKSourceCaptureError

    func capture(
        reference: ArtifactReference,
        at locator: ArtifactLocator,
        relativeTo root: URL?,
        budget: ArtifactAccessBudget
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        throw failure
    }
}
