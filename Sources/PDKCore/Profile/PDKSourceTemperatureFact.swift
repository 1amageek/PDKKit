import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation

/// A source temperature observation, separate from complete operating/characterization PVT.
public struct PDKSourceTemperatureFact: Sendable, Hashable, Codable {
    public let kind: String
    public let temperatureCelsius: Double
    public let sourceReference: ArtifactReference
    public let evidenceIdentity: String
    public init(kind: String, temperatureCelsius: Double, sourceReference: ArtifactReference,
                evidenceIdentity: String, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        if try !work.equal(kind, "operatingTemperature") {
            if try !work.equal(kind, "modelNominalTemperature") {
                guard try work.equal(kind, "circuitNominalTemperature") else { throw .invalidID(work.context(kind)) }
            }
        }
        guard temperatureCelsius.isFinite, temperatureCelsius > -273.15 else { throw .invalidPVT(work.context(evidenceIdentity)) }
        try PDKProfileWire.id(evidenceIdentity, resources: resources)
        try PDKProfileWire.reference(sourceReference, id: evidenceIdentity, resources: resources)
        self.kind = kind; self.temperatureCelsius = temperatureCelsius
        self.sourceReference = sourceReference; self.evidenceIdentity = evidenceIdentity
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, kind, temperatureCelsius, sourceReference, evidenceIdentity }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["kind", "temperatureCelsius", "sourceReference", "evidenceIdentity"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: c.decode(String.self, forKey: .kind), temperatureCelsius: c.decode(Double.self, forKey: .temperatureCelsius),
            sourceReference: c.decode(ArtifactReference.self, forKey: .sourceReference), evidenceIdentity: c.decode(String.self, forKey: .evidenceIdentity), resources: PDKProfileWire.resources(decoder))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion); try c.encode(kind, forKey: .kind)
        try c.encode(temperatureCelsius, forKey: .temperatureCelsius); try c.encode(sourceReference, forKey: .sourceReference)
        try c.encode(evidenceIdentity, forKey: .evidenceIdentity)
    }
}
