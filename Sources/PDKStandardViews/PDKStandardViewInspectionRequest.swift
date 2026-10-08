import Foundation
import PDKCore
import CircuiteFoundation
import CircuiteFoundationFoundation

public struct PDKStandardViewInspectionRequest: Sendable, Codable {
    public static let currentSchemaVersion = 4

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [ArtifactLocator]
    public var format: PDKStandardViewFormat
    public var assetID: String
    public var requireNonEmpty: Bool
    public var expectedLayerNames: [String]
    public var expectedPhysicalLayerNumbers: [Int]
    public var expectedCellNames: [String]
    public var expectedSourceArtifact: ArtifactReference?
    public var projectRootPath: String?

    public init(
        runID: String,
        inputs: [ArtifactLocator],
        format: PDKStandardViewFormat,
        assetID: String = "",
        requireNonEmpty: Bool = true,
        expectedLayerNames: [String] = [],
        expectedPhysicalLayerNumbers: [Int] = [],
        expectedCellNames: [String] = [],
        expectedSourceArtifact: ArtifactReference? = nil,
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
        self.expectedSourceArtifact = expectedSourceArtifact
        self.projectRootPath = projectRootPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported PDK standard-view inspection request schema version: \(schemaVersion)"
            )
        }
        runID = try container.decode(String.self, forKey: .runID)
        inputs = try container.decode([ArtifactLocator].self, forKey: .inputs)
        format = try container.decode(PDKStandardViewFormat.self, forKey: .format)
        assetID = try container.decode(String.self, forKey: .assetID)
        requireNonEmpty = try container.decode(Bool.self, forKey: .requireNonEmpty)
        expectedLayerNames = try container.decode([String].self, forKey: .expectedLayerNames)
        expectedPhysicalLayerNumbers = try container.decode([Int].self, forKey: .expectedPhysicalLayerNumbers)
        expectedCellNames = try container.decode([String].self, forKey: .expectedCellNames)
        expectedSourceArtifact = try container.decodeIfPresent(ArtifactReference.self, forKey: .expectedSourceArtifact)
        projectRootPath = try container.decodeIfPresent(String.self, forKey: .projectRootPath)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case inputs
        case format
        case assetID
        case requireNonEmpty
        case expectedLayerNames
        case expectedPhysicalLayerNumbers
        case expectedCellNames
        case expectedSourceArtifact
        case projectRootPath
    }
}
