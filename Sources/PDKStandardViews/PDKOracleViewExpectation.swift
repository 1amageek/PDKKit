import Foundation

public struct PDKOracleViewExpectation: Sendable, Hashable, Codable {
    public var assetID: String
    public var format: PDKStandardViewFormat
    public var expectedLibraryName: String?
    public var expectedLayerNames: [String]?
    public var expectedPhysicalLayerNumbers: [Int]?
    public var expectedCellNames: [String]?
    public var expectedViaNames: [String]?
    public var expectedModelNames: [String]?
    public var expectedModelTypes: [String]?
    public var expectedModelParameterNames: [String]?
    public var expectedPinNames: [String]?
    public var expectedCornerNames: [String]?
    public var expectedTimingArcCount: Int?
    public var expectedTimingRelatedPinNames: [String]?
    public var expectedTimingTableValueCount: Int?
    public var expectedElementCount: Int?
    public var expectedMetadata: [String: String]?

    public init(
        assetID: String,
        format: PDKStandardViewFormat,
        expectedLibraryName: String? = nil,
        expectedLayerNames: [String]? = nil,
        expectedPhysicalLayerNumbers: [Int]? = nil,
        expectedCellNames: [String]? = nil,
        expectedViaNames: [String]? = nil,
        expectedModelNames: [String]? = nil,
        expectedModelTypes: [String]? = nil,
        expectedModelParameterNames: [String]? = nil,
        expectedPinNames: [String]? = nil,
        expectedCornerNames: [String]? = nil,
        expectedTimingArcCount: Int? = nil,
        expectedTimingRelatedPinNames: [String]? = nil,
        expectedTimingTableValueCount: Int? = nil,
        expectedElementCount: Int? = nil,
        expectedMetadata: [String: String]? = nil
    ) {
        self.assetID = assetID
        self.format = format
        self.expectedLibraryName = expectedLibraryName
        self.expectedLayerNames = expectedLayerNames
        self.expectedPhysicalLayerNumbers = expectedPhysicalLayerNumbers
        self.expectedCellNames = expectedCellNames
        self.expectedViaNames = expectedViaNames
        self.expectedModelNames = expectedModelNames
        self.expectedModelTypes = expectedModelTypes
        self.expectedModelParameterNames = expectedModelParameterNames
        self.expectedPinNames = expectedPinNames
        self.expectedCornerNames = expectedCornerNames
        self.expectedTimingArcCount = expectedTimingArcCount
        self.expectedTimingRelatedPinNames = expectedTimingRelatedPinNames
        self.expectedTimingTableValueCount = expectedTimingTableValueCount
        self.expectedElementCount = expectedElementCount
        self.expectedMetadata = expectedMetadata
    }
}
