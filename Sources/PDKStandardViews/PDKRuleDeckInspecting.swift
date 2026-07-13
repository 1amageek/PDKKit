import Foundation
import XcircuitePackage

public protocol PDKRuleDeckInspecting: Sendable {
    func execute(
        _ request: PDKRuleDeckInspectionRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKRuleDeckInspectionPayload>
}
