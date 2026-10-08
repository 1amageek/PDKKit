import Foundation

/// An untrusted observed mapping bound to one stage-local source occurrence.
public struct PDKConsumedMapping: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let occurrenceID: UInt64
    public let factKind: String
    public let name: String
    public let terminals: [String]
    public let layerNumber: Int?
    public let layerPurpose: PDKLayerPurpose?
    public init(occurrenceID: UInt64, factKind: String, name: String, terminals: [String],
                layerNumber: Int?, layerPurpose: PDKLayerPurpose?,
                resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try PDKProfileWire.id(factKind, resources: resources)
        try PDKProfileWire.id(name, resources: resources)
        for terminal in terminals { try work.step(); try PDKProfileWire.id(terminal, resources: resources) }
        try work.step()
        self.occurrenceID = occurrenceID; self.factKind = factKind; self.name = name
        self.terminals = terminals; self.layerNumber = layerNumber; self.layerPurpose = layerPurpose
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, occurrenceID, factKind, name, terminals, layerNumber, layerPurpose }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["occurrenceID", "factKind", "name", "terminals", "layerNumber", "layerPurpose"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(occurrenceID: c.decode(UInt64.self, forKey: .occurrenceID),
            factKind: c.decode(String.self, forKey: .factKind), name: c.decode(String.self, forKey: .name),
            terminals: c.decode([String].self, forKey: .terminals),
            layerNumber: c.decodeIfPresent(Int.self, forKey: .layerNumber),
            layerPurpose: c.decodeIfPresent(PDKLayerPurpose.self, forKey: .layerPurpose), resources: PDKProfileWire.resources(decoder))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(occurrenceID, forKey: .occurrenceID)
        try c.encode(factKind, forKey: .factKind); try c.encode(name, forKey: .name)
        try c.encode(terminals, forKey: .terminals)
        try c.encode(layerNumber, forKey: .layerNumber); try c.encode(layerPurpose, forKey: .layerPurpose)
    }
}
