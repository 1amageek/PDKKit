import CircuiteFoundation
import Foundation
import PDKStandardViews
import Testing

struct BoundSubstitutingStandardInspector: PDKStandardViewInspecting {
    let removeIdentity: Bool

    func execute(_ request: PDKStandardViewInspectionRequest) async throws -> PDKStandardViewInspectionResult {
        var result = try await LocalPDKStandardViewInspector().execute(request)
        var inspection = try #require(result.payload.inspection)
        let reference = try #require(inspection.sourceArtifact)
        if removeIdentity {
            inspection.sourceArtifact = nil
        } else {
            inspection.sourceArtifact = try ArtifactReference(
                digest: reference.digest,
                byteCount: reference.byteCount,
                descriptor: ArtifactDescriptor(role: .output, kind: reference.kind, format: reference.format)
            )
        }
        result.payload.inspection = inspection
        return result
    }
}
