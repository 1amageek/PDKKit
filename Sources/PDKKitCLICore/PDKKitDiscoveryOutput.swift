import Foundation
import PDKCore
import PDKDiscovery
import CircuiteFoundation

public struct PDKKitDiscoveryOutput: Sendable, Hashable, Codable {
    public var command: String
    public var searchRoots: [String]
    public var requiredProcessID: String?
    public var status: PDKExecutionStatus
    public var diagnostics: [DesignDiagnostic]
    public var payload: PDKDiscoveryPayload

    public init(
        command: String,
        searchRoots: [String],
        requiredProcessID: String?,
        status: PDKExecutionStatus,
        diagnostics: [DesignDiagnostic],
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
