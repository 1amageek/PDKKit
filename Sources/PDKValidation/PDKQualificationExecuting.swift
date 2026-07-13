import Foundation
import CircuiteFoundation

public protocol PDKQualificationExecuting: Sendable {
    func execute(
        _ request: PDKQualificationRequest
    ) async throws -> PDKQualificationExecutionResult
}
