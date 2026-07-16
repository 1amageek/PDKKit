import Foundation

public struct PDKCapabilityReport: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var processID: String
    public var version: String
    public var pdkDigest: String
    public var capabilities: [PDKCapability]
    public var limitations: [String]

    public init(
        schemaVersion: Int = 1,
        processID: String,
        version: String,
        pdkDigest: String,
        capabilities: [PDKCapability] = [],
        limitations: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.processID = processID
        self.version = version
        self.pdkDigest = pdkDigest
        self.capabilities = capabilities
        self.limitations = limitations
    }
}
