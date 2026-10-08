import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKConsumptionClaim: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2
    public let stageRequirement: PDKConsumerRequirement
    public let profileIdentity: ContentDigest
    public let expectedProjectionIdentity: ContentDigest
    public let actualSources: [PDKConsumedSource]
    public let actualMappings: [PDKConsumedMapping]
    public let actualCorners: [PDKProfileCorner]
    public let actualSelections: [PDKProfileSelection]
    public let domainEvidenceReference: ArtifactReference
    public init(stageRequirement: PDKConsumerRequirement, profileIdentity: ContentDigest, expectedProjectionIdentity: ContentDigest, actualSources: [PDKConsumedSource], actualMappings: [PDKConsumedMapping], actualCorners: [PDKProfileCorner], actualSelections: [PDKProfileSelection], domainEvidenceReference: ArtifactReference, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        guard profileIdentity.algorithm == .sha256, expectedProjectionIdentity.algorithm == .sha256 else { throw .noncanonicalEncoding("Digest algorithm") }
        for (index, source) in actualSources.enumerated() {
            try work.step()
            guard source.occurrenceID == UInt64(index) else { throw .noncanonicalEncoding("Consumed occurrence order") }
            if let cornerID = source.cornerID {
                guard try work.contains(actualCorners, where: { (corner) throws(PDKProfileValueError) in
                    try work.equal(corner.cornerID, cornerID)
                }) else { throw .missingSelection("Consumed corner") }
            }
            if let parentID = source.parentOccurrenceID, let edge = source.incomingDependency {
                guard parentID < source.occurrenceID else { throw .noncanonicalEncoding("Consumed parent must precede child") }
                let parent = actualSources[Int(parentID)]
                guard try work.equal(edge.parentSourceKey, parent.sourceKey),
                      try work.equal(edge.parentReference, parent.reference),
                      try work.equal(source.cornerID, parent.cornerID) else {
                    throw .conflictingReference("Consumed parent context")
                }
            }
        }
        for (index, mapping) in actualMappings.enumerated() {
            try work.step()
            guard mapping.occurrenceID < UInt64(actualSources.count) else { throw .missingSelection("Consumed mapping occurrence") }
            for prior in actualMappings[..<index] {
                try work.step()
                guard prior.occurrenceID == mapping.occurrenceID,
                      prior.layerNumber == mapping.layerNumber, prior.layerPurpose == mapping.layerPurpose else { continue }
                if try work.equal(prior.factKind, mapping.factKind), try work.equal(prior.name, mapping.name),
                   try work.equal(prior.terminals, mapping.terminals) { throw .duplicateKey("Consumed mapping record") }
            }
        }
        try work.unique(work.map(actualCorners, { $0.cornerID }))
        try PDKProfileWire.reference(domainEvidenceReference, id: stageRequirement.stageID, resources: resources)
        self.stageRequirement = stageRequirement
        self.profileIdentity = profileIdentity
        self.expectedProjectionIdentity = expectedProjectionIdentity
        self.actualSources = actualSources
        self.actualMappings = actualMappings
        self.actualCorners = actualCorners
        self.actualSelections = actualSelections
        self.domainEvidenceReference = domainEvidenceReference
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, stageRequirement, profileIdentity, expectedProjectionIdentity, actualSources, actualMappings, actualCorners, actualSelections, domainEvidenceReference }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["stageRequirement", "profileIdentity", "expectedProjectionIdentity", "actualSources", "actualMappings", "actualCorners", "actualSelections", "domainEvidenceReference"], schemaVersion: Self.currentSchemaVersion)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            stageRequirement: c.decode(PDKConsumerRequirement.self, forKey: .stageRequirement),
            profileIdentity: c.decode(ContentDigest.self, forKey: .profileIdentity),
            expectedProjectionIdentity: c.decode(ContentDigest.self, forKey: .expectedProjectionIdentity),
            actualSources: c.decode([PDKConsumedSource].self, forKey: .actualSources),
            actualMappings: c.decode([PDKConsumedMapping].self, forKey: .actualMappings),
            actualCorners: c.decode([PDKProfileCorner].self, forKey: .actualCorners),
            actualSelections: c.decode([PDKProfileSelection].self, forKey: .actualSelections),
            domainEvidenceReference: c.decode(ArtifactReference.self, forKey: .domainEvidenceReference),
            resources: PDKProfileWire.resources(decoder)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(stageRequirement, forKey: .stageRequirement)
        try c.encode(profileIdentity, forKey: .profileIdentity)
        try c.encode(expectedProjectionIdentity, forKey: .expectedProjectionIdentity)
        try c.encode(actualSources, forKey: .actualSources)
        try c.encode(actualMappings, forKey: .actualMappings)
        try c.encode(actualCorners, forKey: .actualCorners)
        try c.encode(actualSelections, forKey: .actualSelections)
        try c.encode(domainEvidenceReference, forKey: .domainEvidenceReference)
    }
}
