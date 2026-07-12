import Foundation
import XcircuitePackage

public protocol PDKCorpusValidating: Sendable {
    func execute(
        _ request: PDKCorpusValidationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKCorpusValidationPayload>
}
