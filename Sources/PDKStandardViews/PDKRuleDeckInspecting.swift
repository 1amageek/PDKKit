import Foundation
import CircuiteFoundation

public protocol PDKRuleDeckInspecting: Sendable {
    func execute(
        _ request: PDKRuleDeckInspectionRequest
    ) async throws -> PDKRuleDeckInspectionResult
}
