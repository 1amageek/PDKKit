import Foundation
import CircuiteFoundation

public protocol PDKStandardViewInspecting: Sendable {
    func execute(
        _ request: PDKStandardViewInspectionRequest
    ) async throws -> PDKStandardViewInspectionResult
}
