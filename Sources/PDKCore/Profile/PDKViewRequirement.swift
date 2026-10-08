import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKViewRequirement: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let requirementID: String
    public let purposeID: String
    public let view: PDKViewKind
    public let role: PDKAssetRole
    public let assetIDs: [String]
    public let cornerIDs: [String]
    public let selectedSection: String?
    public let isShared: Bool
    public let allowsMultipleSources: Bool
    public let demandedFactKinds: [String]
    public init(requirementID: String, purposeID: String, view: PDKViewKind, role: PDKAssetRole, assetIDs: [String], cornerIDs: [String], selectedSection: String?, isShared: Bool, allowsMultipleSources: Bool, demandedFactKinds: [String]) throws(PDKProfileValueError) {
        try PDKProfileWire.id(requirementID)
        try PDKProfileWire.id(purposeID)
        try PDKProfileWire.unique(assetIDs)
        try PDKProfileWire.unique(cornerIDs)
        try PDKProfileWire.unique(demandedFactKinds)
        if let selectedSection { try PDKProfileWire.id(selectedSection) }
        guard !assetIDs.isEmpty, !demandedFactKinds.isEmpty, isShared == cornerIDs.isEmpty else { throw .missingSelection(requirementID) }
        self.requirementID = requirementID
        self.purposeID = purposeID
        self.view = view
        self.role = role
        self.assetIDs = assetIDs
        self.cornerIDs = cornerIDs
        self.selectedSection = selectedSection
        self.isShared = isShared
        self.allowsMultipleSources = allowsMultipleSources
        self.demandedFactKinds = demandedFactKinds
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, requirementID, purposeID, view, role, assetIDs, cornerIDs, selectedSection, isShared, allowsMultipleSources, demandedFactKinds }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["requirementID", "purposeID", "view", "role", "assetIDs", "cornerIDs", "selectedSection", "isShared", "allowsMultipleSources", "demandedFactKinds"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            requirementID: c.decode(String.self, forKey: .requirementID),
            purposeID: c.decode(String.self, forKey: .purposeID),
            view: c.decode(PDKViewKind.self, forKey: .view),
            role: c.decode(PDKAssetRole.self, forKey: .role),
            assetIDs: c.decode([String].self, forKey: .assetIDs),
            cornerIDs: c.decode([String].self, forKey: .cornerIDs),
            selectedSection: c.decodeIfPresent(String.self, forKey: .selectedSection),
            isShared: c.decode(Bool.self, forKey: .isShared),
            allowsMultipleSources: c.decode(Bool.self, forKey: .allowsMultipleSources),
            demandedFactKinds: c.decode([String].self, forKey: .demandedFactKinds)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(requirementID, forKey: .requirementID)
        try c.encode(purposeID, forKey: .purposeID)
        try c.encode(view, forKey: .view)
        try c.encode(role, forKey: .role)
        try c.encode(assetIDs, forKey: .assetIDs)
        try c.encode(cornerIDs, forKey: .cornerIDs)
        try c.encode(selectedSection, forKey: .selectedSection)
        try c.encode(isShared, forKey: .isShared)
        try c.encode(allowsMultipleSources, forKey: .allowsMultipleSources)
        try c.encode(demandedFactKinds, forKey: .demandedFactKinds)
    }
}
