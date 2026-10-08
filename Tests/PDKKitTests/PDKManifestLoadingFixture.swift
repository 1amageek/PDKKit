import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import PDKDiscovery
import PDKSourceCapture

func loadPDKReference(for url: URL) async throws -> PDKReference {
    try await LocalPDKManifestLoader().discover(
        at: ArtifactLocator(location: ArtifactLocation(fileURL: url), role: .input, kind: .technology, format: .json),
        relativeTo: nil, captureBudget: PDKSourceCapturePolicy.defaultBudget
    ).reference
}
