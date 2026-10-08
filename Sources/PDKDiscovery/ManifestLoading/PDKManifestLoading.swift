import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation

public protocol PDKManifestLoading: Sendable {
    func discover(at locator: ArtifactLocator, relativeTo root: URL?, captureBudget: ArtifactAccessBudget)
        async throws(PDKManifestLoadingError) -> PDKLoadedManifest
    func loadExact(reference: ArtifactReference, at locator: ArtifactLocator, relativeTo root: URL?, captureBudget: ArtifactAccessBudget)
        async throws(PDKManifestLoadingError) -> PDKLoadedManifest
}
