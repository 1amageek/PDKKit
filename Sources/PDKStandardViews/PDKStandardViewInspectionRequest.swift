import Foundation
import PDKCore
import XcircuitePackage

public struct PDKStandardViewInspectionRequest: XcircuiteEngineRequest {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [XcircuiteFileReference]
    public var format: PDKStandardViewFormat
    public var assetID: String
    public var requireNonEmpty: Bool
    public var expectedLayerNames: [String]
    public var expectedPhysicalLayerNumbers: [Int]
    public var expectedCellNames: [String]
    public var projectRootPath: String?

    public init(
        runID: String,
        inputs: [XcircuiteFileReference],
        format: PDKStandardViewFormat,
        assetID: String = "",
        requireNonEmpty: Bool = true,
        expectedLayerNames: [String] = [],
        expectedPhysicalLayerNumbers: [Int] = [],
        expectedCellNames: [String] = [],
        projectRootPath: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = inputs
        self.format = format
        self.assetID = assetID
        self.requireNonEmpty = requireNonEmpty
        self.expectedLayerNames = Array(Set(expectedLayerNames)).sorted()
        self.expectedPhysicalLayerNumbers = Array(Set(expectedPhysicalLayerNumbers)).sorted()
        self.expectedCellNames = Array(Set(expectedCellNames)).sorted()
        self.projectRootPath = projectRootPath
    }
}
