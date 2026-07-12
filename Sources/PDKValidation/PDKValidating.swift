import Foundation
import XcircuitePackage
import PDKCore

public protocol PDKValidating: Sendable {
    func execute(
        _ request: PDKValidationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKValidationPayload>
}
