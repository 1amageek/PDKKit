import CircuiteFoundation
import PDKCore

public struct PDKProfileCLIAuthoring: Sendable, Codable {
    public static let artifactDescriptor: ArtifactDescriptor = {
        do { return .init(role: .input, kind: try ArtifactKind(rawValue: "pdk.profile-authoring"), format: .json) }
        catch { preconditionFailure("The fixed authoring artifact kind must be valid") }
    }()
    public let profileID: String
    public let requiredCornerIDs: [String]
    public let requirements: [PDKViewRequirement]
    public let orderedSearchRoutes: [String]
    public let inspectionPolicyIdentity: String
    public let candidateSources: [PDKProfileCLICandidateSource]
    public init(profileID: String, requiredCornerIDs: [String], requirements: [PDKViewRequirement],
                orderedSearchRoutes: [String], inspectionPolicyIdentity: String,
                candidateSources: [PDKProfileCLICandidateSource], resources: any PDKAdmissionResourceAccounting) throws {
        try PDKCLIInputCoding.id(profileID, resources: resources)
        try PDKCLIInputCoding.id(inspectionPolicyIdentity, resources: resources)
        try PDKCLIInputCoding.unique(requiredCornerIDs, resources: resources)
        try PDKCLIInputCoding.unique(orderedSearchRoutes, resources: resources)
        for route in orderedSearchRoutes { try PDKCLIInputCoding.route(route, resources: resources) }
        guard !requirements.isEmpty, !candidateSources.isEmpty else { throw PDKProfileCLIInputError.invalidBinding }
        for index in requirements.indices {
            let requirement = requirements[index]
            for prior in requirements[..<index] {
                if try PDKCLIInputCoding.equal(prior.requirementID, requirement.requirementID, resources: resources) { throw PDKProfileCLIInputError.invalidBinding }
            }
            for corner in requirement.cornerIDs {
                var found = false
                for id in requiredCornerIDs { if try PDKCLIInputCoding.equal(corner, id, resources: resources) { found = true; break } }
                guard found else { throw PDKProfileCLIInputError.invalidBinding }
            }
            for asset in requirement.assetIDs {
                var found = false
                for source in candidateSources {
                    if let id = source.assetID, try PDKCLIInputCoding.equal(asset, id, resources: resources) { found = true; break }
                }
                guard found else { throw PDKProfileCLIInputError.invalidBinding }
            }
        }
        for index in candidateSources.indices {
            let source = candidateSources[index]
            for prior in candidateSources[..<index] {
                if try PDKCLIInputCoding.equal(prior.sourceKey, source.sourceKey, resources: resources) { throw PDKProfileCLIInputError.invalidBinding }
                if let first = prior.assetID, let second = source.assetID,
                   try PDKCLIInputCoding.equal(first, second, resources: resources) { throw PDKProfileCLIInputError.invalidBinding }
                for left in prior.logicalRoutes {
                    for right in source.logicalRoutes {
                        if try PDKCLIInputCoding.equal(left, right, resources: resources) { throw PDKProfileCLIInputError.invalidBinding }
                    }
                }
            }
        }
        self.profileID = profileID; self.requiredCornerIDs = requiredCornerIDs; self.requirements = requirements
        self.orderedSearchRoutes = orderedSearchRoutes; self.inspectionPolicyIdentity = inspectionPolicyIdentity
        self.candidateSources = candidateSources
        try resources.check()
    }
    enum CodingKeys: String, CodingKey, CaseIterable { case schemaVersion, profileID, requiredCornerIDs, requirements, orderedSearchRoutes, inspectionPolicyIdentity, candidateSources }
    public init(from decoder: any Decoder) throws {
        let resources = try PDKCLIInputCoding.resources(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try PDKCLIInputCoding.check(c, fields: CodingKeys.allCases)
        try self.init(profileID: c.decode(String.self, forKey: .profileID), requiredCornerIDs: c.decode([String].self, forKey: .requiredCornerIDs),
            requirements: c.decode([PDKViewRequirement].self, forKey: .requirements), orderedSearchRoutes: c.decode([String].self, forKey: .orderedSearchRoutes),
            inspectionPolicyIdentity: c.decode(String.self, forKey: .inspectionPolicyIdentity), candidateSources: c.decode([PDKProfileCLICandidateSource].self, forKey: .candidateSources), resources: resources)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion); try c.encode(profileID, forKey: .profileID)
        try c.encode(requiredCornerIDs, forKey: .requiredCornerIDs); try c.encode(requirements, forKey: .requirements)
        try c.encode(orderedSearchRoutes, forKey: .orderedSearchRoutes)
        try c.encode(inspectionPolicyIdentity, forKey: .inspectionPolicyIdentity); try c.encode(candidateSources, forKey: .candidateSources)
    }
}
