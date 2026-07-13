import Foundation

public protocol PDKExternalStandardViewResultProviding: Sendable {
    func resultData(
        for request: PDKStandardViewInspectionRequest
    ) async throws -> Data
}
