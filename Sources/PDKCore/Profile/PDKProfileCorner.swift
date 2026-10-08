import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKProfileCorner: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let cornerID: String
    public let pvt: PDKPVTCondition
    public init(cornerID: String, pvt: PDKPVTCondition) throws(PDKProfileValueError) {
        try PDKProfileWire.id(cornerID)
        try PDKProfileWire.pvt(pvt, id: cornerID)
        self.cornerID = cornerID
        self.pvt = pvt
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, cornerID, pvt }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["cornerID", "pvt"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            cornerID: c.decode(String.self, forKey: .cornerID),
            pvt: c.decode(PDKPVTCondition.self, forKey: .pvt)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(cornerID, forKey: .cornerID)
        try c.encode(pvt, forKey: .pvt)
    }
}
