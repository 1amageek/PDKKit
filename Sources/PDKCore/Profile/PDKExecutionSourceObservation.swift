import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation

/// Structural data; construction does not authenticate a domain prepared owner.
public struct PDKExecutionSourceObservation: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let executionInputIdentity: ContentDigest
    public let configurationIdentity: String
    public let grammarPolicyIdentity: String
    public let sources: [PDKConsumedSource]
    public init(executionInputIdentity: ContentDigest, configurationIdentity: String, grammarPolicyIdentity: String, sources: [PDKConsumedSource], resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        guard executionInputIdentity.algorithm == .sha256 else { throw .noncanonicalEncoding("Execution input digest algorithm") }
        try PDKProfileWire.id(configurationIdentity, resources: resources)
        try PDKProfileWire.id(grammarPolicyIdentity, resources: resources)
        for (index, source) in sources.enumerated() {
            try work.step()
            for prior in sources[..<index] {
                try work.step()
                guard prior.occurrenceID != source.occurrenceID else { throw .duplicateKey("Execution occurrence") }
            }
            if let parentID = source.parentOccurrenceID, let edge = source.incomingDependency {
                var parent: PDKConsumedSource?
                for prior in sources[..<index] {
                    try work.step()
                    if prior.occurrenceID == parentID { parent = prior; break }
                }
                guard let parent else { throw .noncanonicalEncoding("Execution parent must precede child") }
                guard try work.equal(edge.parentSourceKey, parent.sourceKey),
                      try work.equal(edge.parentReference, parent.reference) else {
                    throw .conflictingReference("Execution parent context")
                }
            }
        }
        self.executionInputIdentity = executionInputIdentity
        self.configurationIdentity = configurationIdentity
        self.grammarPolicyIdentity = grammarPolicyIdentity
        self.sources = sources
        try work.check()
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, executionInputIdentity, configurationIdentity, grammarPolicyIdentity, sources }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["executionInputIdentity", "configurationIdentity", "grammarPolicyIdentity", "sources"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            executionInputIdentity: c.decode(ContentDigest.self, forKey: .executionInputIdentity),
            configurationIdentity: c.decode(String.self, forKey: .configurationIdentity),
            grammarPolicyIdentity: c.decode(String.self, forKey: .grammarPolicyIdentity),
            sources: c.decode([PDKConsumedSource].self, forKey: .sources),
            resources: PDKProfileWire.resources(decoder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(executionInputIdentity, forKey: .executionInputIdentity)
        try c.encode(configurationIdentity, forKey: .configurationIdentity)
        try c.encode(grammarPolicyIdentity, forKey: .grammarPolicyIdentity)
        try c.encode(sources, forKey: .sources)
    }
}
