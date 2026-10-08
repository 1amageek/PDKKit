import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKConsumedSource: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let sourceKey: String
    public let reference: ArtifactReference
    public let selectedSection: String?
    public let preprocessingIdentity: String
    public init(sourceKey: String, reference: ArtifactReference, selectedSection: String?, preprocessingIdentity: String, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try PDKProfileWire.id(sourceKey, resources: resources)
        try PDKProfileWire.id(preprocessingIdentity, resources: resources)
        try PDKProfileWire.reference(reference, id: sourceKey, resources: resources)
        if let selectedSection { try PDKProfileWire.id(selectedSection, resources: resources) }
        self.sourceKey = sourceKey
        self.reference = reference
        self.selectedSection = selectedSection
        self.preprocessingIdentity = preprocessingIdentity
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, sourceKey, reference, selectedSection, preprocessingIdentity }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["sourceKey", "reference", "selectedSection", "preprocessingIdentity"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sourceKey: c.decode(String.self, forKey: .sourceKey),
            reference: c.decode(ArtifactReference.self, forKey: .reference),
            selectedSection: c.decodeIfPresent(String.self, forKey: .selectedSection),
            preprocessingIdentity: c.decode(String.self, forKey: .preprocessingIdentity),
            resources: PDKProfileWire.resources(decoder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(sourceKey, forKey: .sourceKey)
        try c.encode(reference, forKey: .reference)
        try c.encode(selectedSection, forKey: .selectedSection)
        try c.encode(preprocessingIdentity, forKey: .preprocessingIdentity)
    }
}
