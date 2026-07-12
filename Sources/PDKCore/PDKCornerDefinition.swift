import Foundation

public struct PDKCornerDefinition: Sendable, Hashable, Codable {
    public var cornerID: String
    public var pvt: PDKPVTCondition
    public var rcCorner: String?
    public var electromigrationCorner: String?
    public var reliabilityCorner: String?
    public var assetIDs: [String]
    public var viewMappings: [String: String]

    public init(
        cornerID: String,
        pvt: PDKPVTCondition,
        rcCorner: String? = nil,
        electromigrationCorner: String? = nil,
        reliabilityCorner: String? = nil,
        assetIDs: [String] = [],
        viewMappings: [String: String] = [:]
    ) {
        self.cornerID = cornerID
        self.pvt = pvt
        self.rcCorner = rcCorner
        self.electromigrationCorner = electromigrationCorner
        self.reliabilityCorner = reliabilityCorner
        self.assetIDs = assetIDs
        self.viewMappings = viewMappings
    }
}
