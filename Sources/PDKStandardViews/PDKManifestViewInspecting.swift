import Foundation
import XcircuitePackage

public protocol PDKManifestViewInspecting: Sendable {
    func execute(
        _ request: PDKManifestViewInspectionRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKManifestViewInspectionPayload>
}
