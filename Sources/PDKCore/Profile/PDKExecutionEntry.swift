import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation

/// Structural data; construction does not authenticate a domain prepared owner.
public struct PDKExecutionEntry: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let profileRootOccurrenceID: UInt64
    public let executionRootOccurrenceID: UInt64
    public let externalParentOccurrenceID: UInt64?
    public let externalParentReference: ArtifactReference?
    public let incomingDependency: PDKSourceDependency?
    public init(profileRootOccurrenceID: UInt64, executionRootOccurrenceID: UInt64, externalParentOccurrenceID: UInt64?, externalParentReference: ArtifactReference?, incomingDependency: PDKSourceDependency?, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try work.step()
        guard (externalParentOccurrenceID == nil) == (externalParentReference == nil),
              (externalParentOccurrenceID == nil) == (incomingDependency == nil) else {
            throw .noncanonicalEncoding("Execution external entry must be jointly present or null")
        }
        if let reference = externalParentReference, let edge = incomingDependency {
            try PDKProfileWire.reference(reference, id: "Execution parent", resources: resources)
            guard try work.equal(reference, edge.parentReference) else { throw .conflictingReference("Execution external parent") }
        }
        self.profileRootOccurrenceID = profileRootOccurrenceID
        self.executionRootOccurrenceID = executionRootOccurrenceID
        self.externalParentOccurrenceID = externalParentOccurrenceID
        self.externalParentReference = externalParentReference
        self.incomingDependency = incomingDependency
        try work.check()
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, profileRootOccurrenceID, executionRootOccurrenceID, externalParentOccurrenceID, externalParentReference, incomingDependency }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["profileRootOccurrenceID", "executionRootOccurrenceID", "externalParentOccurrenceID", "externalParentReference", "incomingDependency"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            profileRootOccurrenceID: c.decode(UInt64.self, forKey: .profileRootOccurrenceID),
            executionRootOccurrenceID: c.decode(UInt64.self, forKey: .executionRootOccurrenceID),
            externalParentOccurrenceID: c.decodeIfPresent(UInt64.self, forKey: .externalParentOccurrenceID),
            externalParentReference: c.decodeIfPresent(ArtifactReference.self, forKey: .externalParentReference),
            incomingDependency: c.decodeIfPresent(PDKSourceDependency.self, forKey: .incomingDependency),
            resources: PDKProfileWire.resources(decoder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(profileRootOccurrenceID, forKey: .profileRootOccurrenceID)
        try c.encode(executionRootOccurrenceID, forKey: .executionRootOccurrenceID)
        try c.encode(externalParentOccurrenceID, forKey: .externalParentOccurrenceID)
        try c.encode(externalParentReference, forKey: .externalParentReference)
        try c.encode(incomingDependency, forKey: .incomingDependency)
    }
}
