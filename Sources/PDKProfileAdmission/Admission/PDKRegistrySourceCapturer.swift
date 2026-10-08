import CircuiteFoundation
import Foundation
import PDKCore
import PDKSourceCapture

struct PDKRegistrySourceCapturer: PDKBoundedLocalSourceCapturing {
    let registry: PDKProfileSourceRegistry
    func capture(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                 relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                 resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        do { return try await registry.acquire(reference: reference, rootURL: rootURL, rootID: rootID,
            relativePath: relativePath, budget: budget) }
        catch {
            switch error { case .source(let error): throw error
            case .resource(let error): throw .resource(error)
            default: throw .invalidLocation(reason: "Admission registry refused exact binding") }
        }
    }
}
