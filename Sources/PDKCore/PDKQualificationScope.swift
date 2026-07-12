import Foundation

public struct PDKQualificationScope: Sendable, Hashable, Codable {
    public var scopeID: String
    public var processID: String
    public var version: String
    public var pdkDigest: String
    public var qualificationState: PDKQualificationState
    public var capabilityIDs: [String]
    public var layerIDs: [String]
    public var deviceIDs: [String]
    public var cornerIDs: [String]
    public var assetDigests: [String: String]
    public var limitations: [String]
    public var oracleEvidenceIDs: [String]

    public init(
        scopeID: String,
        processID: String,
        version: String,
        pdkDigest: String,
        qualificationState: PDKQualificationState = .unverified,
        capabilityIDs: [String] = [],
        layerIDs: [String] = [],
        deviceIDs: [String] = [],
        cornerIDs: [String] = [],
        assetDigests: [String: String] = [:],
        limitations: [String] = [],
        oracleEvidenceIDs: [String] = []
    ) {
        self.scopeID = scopeID
        self.processID = processID
        self.version = version
        self.pdkDigest = pdkDigest
        self.qualificationState = qualificationState
        self.capabilityIDs = capabilityIDs
        self.layerIDs = layerIDs
        self.deviceIDs = deviceIDs
        self.cornerIDs = cornerIDs
        self.assetDigests = assetDigests
        self.limitations = limitations
        self.oracleEvidenceIDs = oracleEvidenceIDs
    }
}
