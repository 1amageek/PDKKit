import Foundation
import CircuiteFoundation

public protocol PDKManifestViewInspecting: Sendable {
    func execute(
        _ request: PDKManifestViewInspectionRequest
    ) async throws -> PDKManifestViewInspectionResult
}
