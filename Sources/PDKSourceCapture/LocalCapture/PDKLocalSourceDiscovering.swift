import CircuiteFoundation
import Foundation
import PDKCore

/// Observes immutable candidate input; discovery never grants profile admission.
public protocol PDKLocalSourceDiscovering: Sendable {
    func discover(descriptor: ArtifactDescriptor, rootURL: URL, rootID: ArtifactRootID,
                  relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                  resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource
}
