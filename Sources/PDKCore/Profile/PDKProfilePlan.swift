import CircuiteFoundation
import CircuiteFoundationFoundation

/// Pure manifest selection. This value does not authenticate the supplied manifest bytes.
public struct PDKProfilePlan: Sendable, Hashable {
    public let definition: PDKProfileDefinition
    public let manifestReference: ArtifactReference
    public let corners: [PDKProfileCorner]
    public let selections: [PDKProfileSelection]
    public let roots: [PDKProfileSource]
    public let mandatorySupportSourceKeys: [String]
    private let catalog: PDKProfileCatalogSelection
    var storageReservations: [PDKAdmissionReservation] { catalog.storageReservations }

    public init(definition: PDKProfileDefinition, manifest: PDKManifest,
                manifestReference: ArtifactReference,
                resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        guard try work.equal(manifestReference, definition.manifestReference),
              manifest.schemaVersion == PDKManifest.currentSchemaVersion,
              try work.equal(manifest.processID, definition.processID), try work.equal(manifest.version, definition.version) else {
            throw .conflictingReference(work.context(definition.profileID))
        }
        let catalog = try PDKProfileCatalogSelection(manifest: manifest, manifestReference: manifestReference,
            requiredCornerIDs: definition.requiredCornerIDs, requirements: definition.requirements,
            sources: definition.sources, resources: resources)
        self.definition = definition; self.manifestReference = manifestReference
        self.corners = catalog.corners; self.selections = catalog.selections
        self.roots = catalog.roots; self.mandatorySupportSourceKeys = catalog.mandatorySupportSourceKeys
        self.catalog = catalog
        try work.check()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.definition == rhs.definition && lhs.manifestReference == rhs.manifestReference && lhs.corners == rhs.corners
            && lhs.selections == rhs.selections && lhs.roots == rhs.roots && lhs.mandatorySupportSourceKeys == rhs.mandatorySupportSourceKeys
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(definition); hasher.combine(manifestReference); hasher.combine(corners)
        hasher.combine(selections); hasher.combine(roots); hasher.combine(mandatorySupportSourceKeys)
    }
}
