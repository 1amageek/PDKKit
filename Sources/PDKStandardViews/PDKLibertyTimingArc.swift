import Foundation

public struct PDKLibertyTimingArc: Sendable, Hashable, Codable {
    public var cellName: String
    public var pinName: String
    public var relatedPinName: String?
    public var timingType: String?
    public var timingSense: String?
    public var tables: [PDKLibertyTimingTable]

    public init(
        cellName: String,
        pinName: String,
        relatedPinName: String? = nil,
        timingType: String? = nil,
        timingSense: String? = nil,
        tables: [PDKLibertyTimingTable] = []
    ) {
        self.cellName = cellName
        self.pinName = pinName
        self.relatedPinName = relatedPinName
        self.timingType = timingType
        self.timingSense = timingSense
        self.tables = tables.sorted { ($0.kind, $0.pinName) < ($1.kind, $1.pinName) }
    }
}
