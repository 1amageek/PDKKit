import PDKStandardViews

struct BoundThrowingManifestInspector: PDKManifestViewInspecting {
    func execute(_ request: PDKManifestViewInspectionRequest) async throws -> PDKManifestViewInspectionResult {
        throw CancellationError()
    }
}
