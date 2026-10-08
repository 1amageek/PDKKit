import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKSourcePVTFact: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let kind: String
    public let pvt: PDKPVTCondition
    public let sourceReference: ArtifactReference
    public let evidenceIdentity: String
    public init(kind: String, pvt: PDKPVTCondition, sourceReference: ArtifactReference, evidenceIdentity: String) throws(PDKProfileValueError) {
        guard ["operating", "characterization"].contains(kind) else { throw .invalidID(kind) }
        try PDKProfileWire.pvt(pvt, id: evidenceIdentity)
        try PDKProfileWire.id(evidenceIdentity)
        try PDKProfileWire.reference(sourceReference, id: evidenceIdentity)
        self.kind = kind
        self.pvt = pvt
        self.sourceReference = sourceReference
        self.evidenceIdentity = evidenceIdentity
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, kind, pvt, sourceReference, evidenceIdentity }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["kind", "pvt", "sourceReference", "evidenceIdentity"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            kind: c.decode(String.self, forKey: .kind),
            pvt: c.decode(PDKPVTCondition.self, forKey: .pvt),
            sourceReference: c.decode(ArtifactReference.self, forKey: .sourceReference),
            evidenceIdentity: c.decode(String.self, forKey: .evidenceIdentity)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(kind, forKey: .kind)
        try c.encode(pvt, forKey: .pvt)
        try c.encode(sourceReference, forKey: .sourceReference)
        try c.encode(evidenceIdentity, forKey: .evidenceIdentity)
    }
}
