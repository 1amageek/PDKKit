import Foundation
import XcircuitePackage

public protocol PDKOracleComparing: Sendable {
    func execute(
        _ request: PDKOracleRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKOracleComparisonPayload>
}
