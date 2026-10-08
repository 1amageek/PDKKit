import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKProfileSource: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let sourceKey: String
    public let assetID: String?
    public let reference: ArtifactReference
    public let logicalRoutes: [String]
    public init(sourceKey: String, assetID: String?, reference: ArtifactReference, logicalRoutes: [String], resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try PDKProfileWire.id(sourceKey, resources: resources)
        if let assetID { try PDKProfileWire.id(assetID, resources: resources) }
        try PDKProfileWire.reference(reference, id: sourceKey, resources: resources)
        try PDKProfileWire.unique(logicalRoutes, resources: resources)
        guard !logicalRoutes.isEmpty else { throw .invalidRoute(work.context(sourceKey)) }
        for route in logicalRoutes { try PDKProfileWire.route(route, resources: resources) }
        self.sourceKey = sourceKey
        self.assetID = assetID
        self.reference = reference
        self.logicalRoutes = logicalRoutes
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, sourceKey, assetID, reference, logicalRoutes }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["sourceKey", "assetID", "reference", "logicalRoutes"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sourceKey: c.decode(String.self, forKey: .sourceKey),
            assetID: c.decodeIfPresent(String.self, forKey: .assetID),
            reference: c.decode(ArtifactReference.self, forKey: .reference),
            logicalRoutes: c.decode([String].self, forKey: .logicalRoutes),
            resources: PDKProfileWire.resources(decoder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(sourceKey, forKey: .sourceKey)
        try c.encode(assetID, forKey: .assetID)
        try c.encode(reference, forKey: .reference)
        try c.encode(logicalRoutes, forKey: .logicalRoutes)
    }
}
