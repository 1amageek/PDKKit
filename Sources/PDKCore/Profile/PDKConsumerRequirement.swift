import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKConsumerRequirement: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let stageID: String
    public let requirementIDs: [String]
    public let cornerIDs: [String]
    public let configurationIdentity: String
    public init(stageID: String, requirementIDs: [String], cornerIDs: [String], configurationIdentity: String) throws(PDKProfileValueError) {
        try PDKProfileWire.id(stageID)
        try PDKProfileWire.id(configurationIdentity)
        try PDKProfileWire.unique(requirementIDs)
        try PDKProfileWire.unique(cornerIDs)
        guard !requirementIDs.isEmpty else { throw .missingSelection(stageID) }
        self.stageID = stageID
        self.requirementIDs = requirementIDs
        self.cornerIDs = cornerIDs
        self.configurationIdentity = configurationIdentity
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, stageID, requirementIDs, cornerIDs, configurationIdentity }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["stageID", "requirementIDs", "cornerIDs", "configurationIdentity"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            stageID: c.decode(String.self, forKey: .stageID),
            requirementIDs: c.decode([String].self, forKey: .requirementIDs),
            cornerIDs: c.decode([String].self, forKey: .cornerIDs),
            configurationIdentity: c.decode(String.self, forKey: .configurationIdentity)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(stageID, forKey: .stageID)
        try c.encode(requirementIDs, forKey: .requirementIDs)
        try c.encode(cornerIDs, forKey: .cornerIDs)
        try c.encode(configurationIdentity, forKey: .configurationIdentity)
    }
}
