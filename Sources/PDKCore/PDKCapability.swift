import Foundation

public struct PDKCapability: Sendable, Hashable, Codable {
    public var capabilityID: String
    public var status: PDKCapabilityStatus
    public var evidenceAssetIDs: [String]
    public var limitation: String?

    public init(
        capabilityID: String,
        status: PDKCapabilityStatus,
        evidenceAssetIDs: [String] = [],
        limitation: String? = nil
    ) {
        self.capabilityID = capabilityID
        self.status = status
        self.evidenceAssetIDs = evidenceAssetIDs
        self.limitation = limitation
    }
}
