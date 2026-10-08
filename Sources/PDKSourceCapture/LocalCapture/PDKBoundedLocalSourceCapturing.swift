import CircuiteFoundation
import Foundation
import PDKCore

/// Exact source admission under explicit root authority and shared invocation limits.
public protocol PDKBoundedLocalSourceCapturing: Sendable {
    func capture(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                 relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                 resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource
}
