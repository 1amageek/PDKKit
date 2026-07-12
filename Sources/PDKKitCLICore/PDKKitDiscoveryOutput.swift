import Foundation
import PDKDiscovery
import XcircuitePackage

public struct PDKKitDiscoveryOutput: Sendable, Hashable, Codable {
    public var command: String
    public var searchRoots: [String]
    public var requiredProcessID: String?
    public var status: XcircuiteEngineExecutionStatus
    public var diagnostics: [XcircuiteEngineDiagnostic]
    public var payload: PDKDiscoveryPayload

    public init(
        command: String,
        searchRoots: [String],
        requiredProcessID: String?,
        status: XcircuiteEngineExecutionStatus,
        diagnostics: [XcircuiteEngineDiagnostic],
        payload: PDKDiscoveryPayload
    ) {
        self.command = command
        self.searchRoots = searchRoots
        self.requiredProcessID = requiredProcessID
        self.status = status
        self.diagnostics = diagnostics
        self.payload = payload
    }
}
