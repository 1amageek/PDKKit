import Foundation
import XcircuitePackage

public protocol PDKStandardViewInspecting: Sendable {
    func execute(
        _ request: PDKStandardViewInspectionRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKStandardViewInspectionPayload>
}
