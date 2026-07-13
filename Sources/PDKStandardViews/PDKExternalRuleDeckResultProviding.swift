import Foundation

public protocol PDKExternalRuleDeckResultProviding: Sendable {
    func resultData(
        for request: PDKRuleDeckInspectionRequest
    ) async throws -> Data
}
