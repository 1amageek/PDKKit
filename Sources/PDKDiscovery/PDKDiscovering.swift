import Foundation
import XcircuitePackage
import PDKCore

public protocol PDKDiscovering: Sendable {
    func execute(
        _ request: PDKDiscoveryRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKDiscoveryPayload>
}
