import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
public struct PDKProfileDefinition: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2
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
    public let initialPreprocessingIdentity: String
    public init(profileID: String, manifestReference: ArtifactReference, processID: String, version: String, requiredCornerIDs: [String], requirements: [PDKViewRequirement], sources: [PDKProfileSource], orderedSearchRoutes: [String], dependencies: [PDKSourceDependency], inspectionPolicyIdentity: String, initialPreprocessingIdentity: String, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try PDKProfileWire.id(profileID, resources: resources)
        try PDKProfileWire.id(processID, resources: resources)
        try PDKProfileWire.id(version, resources: resources)
        try PDKProfileWire.id(inspectionPolicyIdentity, resources: resources)
        try PDKProfileWire.id(initialPreprocessingIdentity, resources: resources)
        try PDKProfileWire.reference(manifestReference, id: profileID, resources: resources)
        guard manifestReference.descriptor.format == .json,
              try work.technologyKind(manifestReference.descriptor.kind) else { throw .conflictingReference(work.context(profileID)) }
        try work.unique(requiredCornerIDs)
        try work.unique(work.map(requirements, { $0.requirementID }))
        try work.unique(work.map(sources, { $0.sourceKey }))
        try work.temporary(String.self, capacity: sources.count)
        var assetIDs: [String] = []; assetIDs.reserveCapacity(sources.count)
        for source in sources { try work.step(); if let id = source.assetID { assetIDs.append(id) } }
        try work.unique(assetIDs)
        try work.unique(orderedSearchRoutes)
        for route in orderedSearchRoutes { try PDKProfileWire.route(route, resources: resources) }
        guard !requirements.isEmpty, !sources.isEmpty else { throw .missingSelection(work.context(profileID)) }
        var priorOrder: UInt64?
        for edge in dependencies {
            try work.step()
            guard let parent = try work.first(sources, where: { (source) throws(PDKProfileValueError) in try work.equal(source.sourceKey, edge.parentSourceKey) }),
                  let child = try work.first(sources, where: { (source) throws(PDKProfileValueError) in try work.equal(source.sourceKey, edge.childSourceKey) }),
                  try work.equal(parent.reference, edge.parentReference),
                  try work.equal(child.reference, edge.childReference) else { throw .conflictingReference(work.context(edge.childSourceKey)) }
            if let priorOrder, priorOrder >= edge.lexicalOrder { throw .noncanonicalEncoding("Dependency lexical order") }
            priorOrder = edge.lexicalOrder
        }
        for r in requirements {
            try work.step()
            for corner in r.cornerIDs {
                guard try work.contains(requiredCornerIDs, where: { (id) throws(PDKProfileValueError) in try work.equal(id, corner) }) else { throw .missingSelection(work.context(r.requirementID)) }
            }
            for asset in r.assetIDs {
                guard try work.contains(sources, where: { (source) throws(PDKProfileValueError) in try work.equal(source.assetID, asset) }) else { throw .missingSelection(work.context(asset)) }
            }
        }
        try work.check()
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
        self.initialPreprocessingIdentity = initialPreprocessingIdentity
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, profileID, manifestReference, processID, version, requiredCornerIDs, requirements, sources, orderedSearchRoutes, dependencies, inspectionPolicyIdentity, initialPreprocessingIdentity }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["profileID", "manifestReference", "processID", "version", "requiredCornerIDs", "requirements", "sources", "orderedSearchRoutes", "dependencies", "inspectionPolicyIdentity", "initialPreprocessingIdentity"], schemaVersion: Self.currentSchemaVersion)
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
            inspectionPolicyIdentity: c.decode(String.self, forKey: .inspectionPolicyIdentity),
            initialPreprocessingIdentity: c.decode(String.self, forKey: .initialPreprocessingIdentity),
            resources: PDKProfileWire.resources(decoder)
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
        try c.encode(initialPreprocessingIdentity, forKey: .initialPreprocessingIdentity)
    }
}
