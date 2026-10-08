import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKProfileSelection: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let requirementID: String
    public let cornerID: String?
    public let assetIDs: [String]
    public let sourceKeys: [String]
    public let selectedSection: String?
    public init(requirementID: String, cornerID: String?, assetIDs: [String], sourceKeys: [String], selectedSection: String?) throws(PDKProfileValueError) {
        try PDKProfileWire.id(requirementID)
        try PDKProfileWire.unique(assetIDs)
        try PDKProfileWire.unique(sourceKeys)
        guard !assetIDs.isEmpty, assetIDs.count == sourceKeys.count else { throw .missingSelection(requirementID) }
        if let cornerID { try PDKProfileWire.id(cornerID) }
        if let selectedSection { try PDKProfileWire.id(selectedSection) }
        self.requirementID = requirementID
        self.cornerID = cornerID
        self.assetIDs = assetIDs
        self.sourceKeys = sourceKeys
        self.selectedSection = selectedSection
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, requirementID, cornerID, assetIDs, sourceKeys, selectedSection }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["requirementID", "cornerID", "assetIDs", "sourceKeys", "selectedSection"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            requirementID: c.decode(String.self, forKey: .requirementID),
            cornerID: c.decodeIfPresent(String.self, forKey: .cornerID),
            assetIDs: c.decode([String].self, forKey: .assetIDs),
            sourceKeys: c.decode([String].self, forKey: .sourceKeys),
            selectedSection: c.decodeIfPresent(String.self, forKey: .selectedSection)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(requirementID, forKey: .requirementID)
        try c.encode(cornerID, forKey: .cornerID)
        try c.encode(assetIDs, forKey: .assetIDs)
        try c.encode(sourceKeys, forKey: .sourceKeys)
        try c.encode(selectedSection, forKey: .selectedSection)
    }
}
