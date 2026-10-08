import CircuiteFoundation
import Foundation
import PDKCore

public protocol PDKBoundedManifestLoading: Sendable {
    func discover(descriptor: ArtifactDescriptor, rootURL: URL, rootID: ArtifactRootID,
                  relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                  resources: any PDKAdmissionResourceAccounting)
        async throws(PDKBoundedManifestLoadingError) -> PDKBoundedLoadedManifest
    func loadExact(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                   relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                   resources: any PDKAdmissionResourceAccounting)
        async throws(PDKBoundedManifestLoadingError) -> PDKBoundedLoadedManifest
}
