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
    public init(requirementID: String, cornerID: String?, assetIDs: [String], sourceKeys: [String], selectedSection: String?, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try PDKProfileWire.id(requirementID, resources: resources)
        try PDKProfileWire.unique(assetIDs, resources: resources)
        try PDKProfileWire.unique(sourceKeys, resources: resources)
        guard !assetIDs.isEmpty, assetIDs.count == sourceKeys.count else { throw .missingSelection(work.context(requirementID)) }
        if let cornerID { try PDKProfileWire.id(cornerID, resources: resources) }
        if let selectedSection { try PDKProfileWire.id(selectedSection, resources: resources) }
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
            selectedSection: c.decodeIfPresent(String.self, forKey: .selectedSection),
            resources: PDKProfileWire.resources(decoder)
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
