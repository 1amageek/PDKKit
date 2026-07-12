import Foundation
import XcircuitePackage

public protocol PDKQualificationExecuting: Sendable {
    func execute(
        _ request: PDKQualificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKQualificationAssessment>
}
