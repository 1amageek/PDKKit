import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKConsumptionClaim: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let stageRequirement: PDKConsumerRequirement
    public let profileIdentity: ContentDigest
    public let expectedProjectionIdentity: ContentDigest
    public let actualSources: [PDKConsumedSource]
    public let actualCorners: [PDKProfileCorner]
    public let actualSelections: [PDKProfileSelection]
    public let domainEvidenceReference: ArtifactReference
    public init(stageRequirement: PDKConsumerRequirement, profileIdentity: ContentDigest, expectedProjectionIdentity: ContentDigest, actualSources: [PDKConsumedSource], actualCorners: [PDKProfileCorner], actualSelections: [PDKProfileSelection], domainEvidenceReference: ArtifactReference, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        guard profileIdentity.algorithm == .sha256, expectedProjectionIdentity.algorithm == .sha256 else { throw .noncanonicalEncoding("Digest algorithm") }
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        for (index, source) in actualSources.enumerated() {
            try work.step()
            for prior in actualSources[..<index] {
                if try work.equal(prior.sourceKey, source.sourceKey),
                   try work.equal(prior.selectedSection, source.selectedSection),
                   try work.equal(prior.preprocessingIdentity, source.preprocessingIdentity) {
                    throw .duplicateKey("consumed source context")
                }
            }
        }
        try work.unique(work.map(actualCorners, { $0.cornerID }))
        try PDKProfileWire.reference(domainEvidenceReference, id: stageRequirement.stageID, resources: resources)
        self.stageRequirement = stageRequirement
        self.profileIdentity = profileIdentity
        self.expectedProjectionIdentity = expectedProjectionIdentity
        self.actualSources = actualSources
        self.actualCorners = actualCorners
        self.actualSelections = actualSelections
        self.domainEvidenceReference = domainEvidenceReference
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, stageRequirement, profileIdentity, expectedProjectionIdentity, actualSources, actualCorners, actualSelections, domainEvidenceReference }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["stageRequirement", "profileIdentity", "expectedProjectionIdentity", "actualSources", "actualCorners", "actualSelections", "domainEvidenceReference"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            stageRequirement: c.decode(PDKConsumerRequirement.self, forKey: .stageRequirement),
            profileIdentity: c.decode(ContentDigest.self, forKey: .profileIdentity),
            expectedProjectionIdentity: c.decode(ContentDigest.self, forKey: .expectedProjectionIdentity),
            actualSources: c.decode([PDKConsumedSource].self, forKey: .actualSources),
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
        try c.encode(actualCorners, forKey: .actualCorners)
        try c.encode(actualSelections, forKey: .actualSelections)
        try c.encode(domainEvidenceReference, forKey: .domainEvidenceReference)
    }
}
