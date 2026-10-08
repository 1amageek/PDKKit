import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKProfileDefinition: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let profileID: String
    public let manifestReference: ArtifactReference
    public let processID: String
    public let version: String
    public let requiredCornerIDs: [String]
    public let requirements: [PDKViewRequirement]
    public let sources: [PDKProfileSource]
    public let orderedSearchRoutes: [String]
    public let dependencies: [PDKSourceDependency]
    public let inspectionPolicyIdentity: String
    public init(profileID: String, manifestReference: ArtifactReference, processID: String, version: String, requiredCornerIDs: [String], requirements: [PDKViewRequirement], sources: [PDKProfileSource], orderedSearchRoutes: [String], dependencies: [PDKSourceDependency], inspectionPolicyIdentity: String) throws(PDKProfileValueError) {
        for id in [profileID, processID, version, inspectionPolicyIdentity] { try PDKProfileWire.id(id) }
        try PDKProfileWire.reference(manifestReference, id: profileID)
        guard manifestReference.descriptor.format == .json,
              PDKIdentityDescriptorPolicy.normalizedKind(manifestReference.descriptor.kind) == "pdk.technology" else { throw .conflictingReference(profileID) }
        try PDKProfileWire.unique(requiredCornerIDs)
        try PDKProfileWire.unique(requirements.map(\.requirementID))
        try PDKProfileWire.unique(sources.map(\.sourceKey))
        try PDKProfileWire.unique(sources.compactMap(\.assetID))
        try PDKProfileWire.unique(orderedSearchRoutes)
        for route in orderedSearchRoutes { try PDKProfileWire.route(route) }
        guard !requirements.isEmpty, !sources.isEmpty else { throw .missingSelection(profileID) }
        let table = Dictionary(uniqueKeysWithValues: sources.map { ($0.sourceKey, $0) })
        for edge in dependencies {
            guard table[edge.parentSourceKey]?.reference == edge.parentReference,
                  table[edge.childSourceKey]?.reference == edge.childReference else { throw .conflictingReference(edge.childSourceKey) }
        }
        try PDKProfileWire.unique(dependencies.map { String($0.lexicalOrder) })
        guard dependencies.map(\.lexicalOrder) == dependencies.map(\.lexicalOrder).sorted() else { throw .noncanonicalEncoding("Dependency lexical order") }
        for r in requirements {
            guard Set(r.cornerIDs).isSubset(of: Set(requiredCornerIDs)) else { throw .missingSelection(r.requirementID) }
            for asset in r.assetIDs where !sources.contains(where: { $0.assetID == asset }) { throw .missingSelection(asset) }
        }
        self.profileID = profileID
        self.manifestReference = manifestReference
        self.processID = processID
        self.version = version
        self.requiredCornerIDs = requiredCornerIDs
        self.requirements = requirements
        self.sources = sources
        self.orderedSearchRoutes = orderedSearchRoutes
        self.dependencies = dependencies
        self.inspectionPolicyIdentity = inspectionPolicyIdentity
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, profileID, manifestReference, processID, version, requiredCornerIDs, requirements, sources, orderedSearchRoutes, dependencies, inspectionPolicyIdentity }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["profileID", "manifestReference", "processID", "version", "requiredCornerIDs", "requirements", "sources", "orderedSearchRoutes", "dependencies", "inspectionPolicyIdentity"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            profileID: c.decode(String.self, forKey: .profileID),
            manifestReference: c.decode(ArtifactReference.self, forKey: .manifestReference),
            processID: c.decode(String.self, forKey: .processID),
            version: c.decode(String.self, forKey: .version),
            requiredCornerIDs: c.decode([String].self, forKey: .requiredCornerIDs),
            requirements: c.decode([PDKViewRequirement].self, forKey: .requirements),
            sources: c.decode([PDKProfileSource].self, forKey: .sources),
            orderedSearchRoutes: c.decode([String].self, forKey: .orderedSearchRoutes),
            dependencies: c.decode([PDKSourceDependency].self, forKey: .dependencies),
            inspectionPolicyIdentity: c.decode(String.self, forKey: .inspectionPolicyIdentity)
        )
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(profileID, forKey: .profileID)
        try c.encode(manifestReference, forKey: .manifestReference)
        try c.encode(processID, forKey: .processID)
        try c.encode(version, forKey: .version)
        try c.encode(requiredCornerIDs, forKey: .requiredCornerIDs)
        try c.encode(requirements, forKey: .requirements)
        try c.encode(sources, forKey: .sources)
        try c.encode(orderedSearchRoutes, forKey: .orderedSearchRoutes)
        try c.encode(dependencies, forKey: .dependencies)
        try c.encode(inspectionPolicyIdentity, forKey: .inspectionPolicyIdentity)
    }
}
