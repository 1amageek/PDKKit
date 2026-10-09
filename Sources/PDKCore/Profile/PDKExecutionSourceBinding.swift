import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation

/// Structural data; construction does not authenticate a domain prepared owner.
public struct PDKExecutionSourceBinding: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let profileOccurrenceID: UInt64
    public let executionOccurrenceID: UInt64
    public init(profileOccurrenceID: UInt64, executionOccurrenceID: UInt64, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try work.step()
        self.profileOccurrenceID = profileOccurrenceID
        self.executionOccurrenceID = executionOccurrenceID
        try work.check()
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, profileOccurrenceID, executionOccurrenceID }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["profileOccurrenceID", "executionOccurrenceID"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            profileOccurrenceID: c.decode(UInt64.self, forKey: .profileOccurrenceID),
            executionOccurrenceID: c.decode(UInt64.self, forKey: .executionOccurrenceID),
            resources: PDKProfileWire.resources(decoder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(profileOccurrenceID, forKey: .profileOccurrenceID)
        try c.encode(executionOccurrenceID, forKey: .executionOccurrenceID)
    }
}
