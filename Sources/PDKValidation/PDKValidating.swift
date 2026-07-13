import Foundation
import CircuiteFoundation
import PDKCore

public protocol PDKValidating: Sendable {
    func execute(
        _ request: PDKValidationRequest
    ) async throws -> PDKValidationExecutionResult
}
