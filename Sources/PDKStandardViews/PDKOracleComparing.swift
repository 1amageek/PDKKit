import Foundation
import CircuiteFoundation

public protocol PDKOracleComparing: Sendable {
    func execute(
        _ request: PDKOracleRequest
    ) async throws -> PDKOracleComparisonResult
}
