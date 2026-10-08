import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKConsumedSource: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2
    public let occurrenceID: UInt64
    public let sourceKey: String
    public let reference: ArtifactReference
    public let cornerID: String?
    public let selectedSection: String?
    public let preprocessingIdentity: String
    public let parentOccurrenceID: UInt64?
    public let incomingDependency: PDKSourceDependency?
    public init(occurrenceID: UInt64, sourceKey: String, reference: ArtifactReference, cornerID: String?,
                selectedSection: String?, preprocessingIdentity: String, parentOccurrenceID: UInt64?,
                incomingDependency: PDKSourceDependency?, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try PDKProfileWire.id(sourceKey, resources: resources)
        try PDKProfileWire.id(preprocessingIdentity, resources: resources)
        try PDKProfileWire.reference(reference, id: sourceKey, resources: resources)
        if let selectedSection { try PDKProfileWire.id(selectedSection, resources: resources) }
        if let cornerID { try PDKProfileWire.id(cornerID, resources: resources) }
        try work.step()
        guard (parentOccurrenceID == nil) == (incomingDependency == nil) else {
            throw .noncanonicalEncoding("Consumed parent and dependency must be paired")
        }
        if let edge = incomingDependency {
            guard try work.equal(edge.childSourceKey, sourceKey),
                  try work.equal(edge.childReference, reference),
                  try work.equal(edge.selectedSection, selectedSection),
                  try work.equal(edge.preprocessingIdentity, preprocessingIdentity) else {
                throw .conflictingReference("Consumed incoming child context")
            }
        }
        self.occurrenceID = occurrenceID; self.cornerID = cornerID
        self.parentOccurrenceID = parentOccurrenceID; self.incomingDependency = incomingDependency
        self.sourceKey = sourceKey
        self.reference = reference
        self.selectedSection = selectedSection
        self.preprocessingIdentity = preprocessingIdentity
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, occurrenceID, sourceKey, reference, cornerID, selectedSection, preprocessingIdentity, parentOccurrenceID, incomingDependency }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["occurrenceID", "sourceKey", "reference", "cornerID", "selectedSection", "preprocessingIdentity", "parentOccurrenceID", "incomingDependency"], schemaVersion: Self.currentSchemaVersion)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            occurrenceID: c.decode(UInt64.self, forKey: .occurrenceID),
            sourceKey: c.decode(String.self, forKey: .sourceKey),
            reference: c.decode(ArtifactReference.self, forKey: .reference),
            cornerID: c.decodeIfPresent(String.self, forKey: .cornerID),
            selectedSection: c.decodeIfPresent(String.self, forKey: .selectedSection),
            preprocessingIdentity: c.decode(String.self, forKey: .preprocessingIdentity),
            parentOccurrenceID: c.decodeIfPresent(UInt64.self, forKey: .parentOccurrenceID),
            incomingDependency: c.decodeIfPresent(PDKSourceDependency.self, forKey: .incomingDependency),
            resources: PDKProfileWire.resources(decoder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(occurrenceID, forKey: .occurrenceID)
        try c.encode(sourceKey, forKey: .sourceKey)
        try c.encode(reference, forKey: .reference)
        try c.encode(cornerID, forKey: .cornerID)
        try c.encode(selectedSection, forKey: .selectedSection)
        try c.encode(preprocessingIdentity, forKey: .preprocessingIdentity)
        try c.encode(parentOccurrenceID, forKey: .parentOccurrenceID)
        try c.encode(incomingDependency, forKey: .incomingDependency)
    }
}
