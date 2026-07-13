import Foundation
import CircuiteFoundation
import PDKCore

public protocol PDKDiscovering: Sendable {
    func execute(
        _ request: PDKDiscoveryRequest
    ) async throws -> PDKDiscoveryResult
}
