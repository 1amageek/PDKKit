import Foundation

public struct PDKLibertyTimingTable: Sendable, Hashable, Codable {
    public var cellName: String
    public var pinName: String
    public var relatedPinName: String?
    public var kind: String
    public var index1: [Double]
    public var index2: [Double]
    public var index3: [Double]
    public var values: [Double]
    public var rawIndex1: [String]
    public var rawIndex2: [String]
    public var rawIndex3: [String]
    public var rawValues: [String]

    public init(
        cellName: String,
        pinName: String,
        relatedPinName: String? = nil,
        kind: String,
        index1: [Double] = [],
        index2: [Double] = [],
        index3: [Double] = [],
        values: [Double] = [],
        rawIndex1: [String] = [],
        rawIndex2: [String] = [],
        rawIndex3: [String] = [],
        rawValues: [String] = []
    ) {
        self.cellName = cellName
        self.pinName = pinName
        self.relatedPinName = relatedPinName
        self.kind = kind
        self.index1 = index1
        self.index2 = index2
        self.index3 = index3
        self.values = values
        self.rawIndex1 = rawIndex1
        self.rawIndex2 = rawIndex2
        self.rawIndex3 = rawIndex3
        self.rawValues = rawValues
    }

    public var hasCompleteNumericSemantics: Bool {
        rawIndex1.count == index1.count &&
            rawIndex2.count == index2.count &&
            rawIndex3.count == index3.count &&
            rawValues.count == values.count &&
            !rawValues.isEmpty
    }

    public var expectedValueCount: Int {
        [index1.count, index2.count, index3.count]
            .filter { $0 > 0 }
            .reduce(1, *)
    }

    public var hasConsistentDimensions: Bool {
        values.count == expectedValueCount
    }
}
