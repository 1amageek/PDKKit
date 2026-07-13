import Foundation
import CircuiteFoundation

public protocol PDKCorpusValidating: Sendable {
    func execute(
        _ request: PDKCorpusValidationRequest
    ) async throws -> PDKCorpusValidationExecutionResult
}
