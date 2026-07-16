import Foundation
import CircuiteFoundation
import PDKCore

public struct PDKDiscoveryRequest: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [ArtifactLocator]

    public var searchRoots: [String]
    public var requiredProcessID: String?
    public var manifestFileNames: [String]

    public init(
        runID: String,
        inputs: [ArtifactLocator],
        searchRoots: [String],
        requiredProcessID: String? = nil,
        manifestFileNames: [String] = [PDKManifest.fileName, "pdk-manifest.json", "manifest.json"]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = inputs
        self.searchRoots = searchRoots
        self.requiredProcessID = requiredProcessID
        self.manifestFileNames = manifestFileNames
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported PDK discovery request schema version: \(schemaVersion)"
            )
        }
        runID = try container.decode(String.self, forKey: .runID)
        inputs = try container.decode([ArtifactLocator].self, forKey: .inputs)
        searchRoots = try container.decode([String].self, forKey: .searchRoots)
        requiredProcessID = try container.decodeIfPresent(String.self, forKey: .requiredProcessID)
        manifestFileNames = try container.decode([String].self, forKey: .manifestFileNames)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case inputs
        case searchRoots
        case requiredProcessID
        case manifestFileNames
    }
}
