import Foundation
import XcircuitePackage
import PDKCore

public struct PDKDiscoveryRequest: XcircuiteEngineRequest {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [XcircuiteFileReference]

    public var searchRoots: [String]
    public var requiredProcessID: String?
    public var manifestFileNames: [String]

    public init(
        runID: String,
        inputs: [XcircuiteFileReference],
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
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        runID = try container.decode(String.self, forKey: .runID)
        inputs = try container.decodeIfPresent([XcircuiteFileReference].self, forKey: .inputs) ?? []
        searchRoots = try container.decodeIfPresent([String].self, forKey: .searchRoots) ?? []
        requiredProcessID = try container.decodeIfPresent(String.self, forKey: .requiredProcessID)
        manifestFileNames = try container.decodeIfPresent([String].self, forKey: .manifestFileNames)
            ?? [PDKManifest.fileName, "pdk-manifest.json", "manifest.json"]
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
