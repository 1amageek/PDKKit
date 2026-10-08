import CircuiteFoundation
import Foundation
import PDKCore
@testable import PDKProfileAdmission
import PDKSourceCapture
import Synchronization

final class StandardCaptureProbe: PDKBoundedLocalSourceCapturing {
    private struct State { var resources: LocalPDKAdmissionResources? }
    private let state = Mutex(State())
    let deleteTechnology: Bool
    init(deleteTechnology: Bool = false) { self.deleteTechnology = deleteTechnology }
    var resources: LocalPDKAdmissionResources? { state.withLock { $0.resources } }
    func capture(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID, relativePath: ArtifactRelativePath,
                 budget: ArtifactAccessBudget, resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        state.withLock { $0.resources = resources as? LocalPDKAdmissionResources }
        let source = try await LocalPDKBoundedSourceCapturer().capture(reference: reference, rootURL: rootURL,
            rootID: rootID, relativePath: relativePath, budget: budget, resources: resources)
        if deleteTechnology, reference.descriptor.format == .json, relativePath.segments == ["technology.json"] {
            do { try FileManager.default.removeItem(at: rootURL.appending(path: "technology.json")) }
            catch { throw .invalidLocation(reason: "Test fixture removal failed") }
        }
        return source
    }
}
