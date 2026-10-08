import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation

public protocol PDKLocalSourceCapturing: Sendable {
    func capture(
        reference: ArtifactReference,
        at locator: ArtifactLocator,
        relativeTo root: URL?,
        budget: ArtifactAccessBudget
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource
}
