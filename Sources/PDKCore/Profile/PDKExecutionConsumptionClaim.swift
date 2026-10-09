import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation

/// Structural data; construction does not authenticate a domain prepared owner.
public struct PDKExecutionConsumptionClaim: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let scopedClaim: PDKConsumptionClaim
    public let executionInputIdentity: ContentDigest
    public let sourceBindings: [PDKExecutionSourceBinding]
    public let entries: [PDKExecutionEntry]
    public init(scopedClaim: PDKConsumptionClaim, executionInputIdentity: ContentDigest, sourceBindings: [PDKExecutionSourceBinding], entries: [PDKExecutionEntry], resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        guard executionInputIdentity.algorithm == .sha256 else { throw .noncanonicalEncoding("Execution input digest algorithm") }
        guard sourceBindings.count == scopedClaim.actualSources.count else { throw .noncanonicalEncoding("Execution binding count") }
        for (index, binding) in sourceBindings.enumerated() {
            try work.step()
            guard binding.profileOccurrenceID == UInt64(index) else { throw .noncanonicalEncoding("Execution binding order") }
            for prior in sourceBindings[..<index] {
                try work.step()
                guard prior.executionOccurrenceID != binding.executionOccurrenceID else { throw .duplicateKey("Execution binding occurrence") }
            }
        }
        var rootIndex = 0
        for source in scopedClaim.actualSources {
            try work.step()
            guard source.parentOccurrenceID == nil else { continue }
            guard rootIndex < entries.count else { throw .missingSelection("Execution root entry") }
            let entry = entries[rootIndex]
            guard entry.profileRootOccurrenceID == source.occurrenceID,
                  entry.executionRootOccurrenceID == sourceBindings[Int(source.occurrenceID)].executionOccurrenceID else {
                throw .noncanonicalEncoding("Execution root entry order")
            }
            rootIndex += 1
        }
        guard rootIndex == entries.count else { throw .noncanonicalEncoding("Extra execution root entry") }
        self.scopedClaim = scopedClaim
        self.executionInputIdentity = executionInputIdentity
        self.sourceBindings = sourceBindings
        self.entries = entries
        try work.check()
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, scopedClaim, executionInputIdentity, sourceBindings, entries }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["scopedClaim", "executionInputIdentity", "sourceBindings", "entries"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            scopedClaim: c.decode(PDKConsumptionClaim.self, forKey: .scopedClaim),
            executionInputIdentity: c.decode(ContentDigest.self, forKey: .executionInputIdentity),
            sourceBindings: c.decode([PDKExecutionSourceBinding].self, forKey: .sourceBindings),
            entries: c.decode([PDKExecutionEntry].self, forKey: .entries),
            resources: PDKProfileWire.resources(decoder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(scopedClaim, forKey: .scopedClaim)
        try c.encode(executionInputIdentity, forKey: .executionInputIdentity)
        try c.encode(sourceBindings, forKey: .sourceBindings)
        try c.encode(entries, forKey: .entries)
    }
}
