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

    public init(definition: PDKProfileDefinition, manifest: PDKManifest,
                manifestReference: ArtifactReference) throws(PDKProfileValueError) {
        guard manifestReference == definition.manifestReference,
              manifest.schemaVersion == PDKManifest.currentSchemaVersion,
              manifest.processID == definition.processID, manifest.version == definition.version else {
            throw .conflictingReference(definition.profileID)
        }
        try PDKProfileWire.unique(manifest.assets.map(\.assetID))
        try PDKProfileWire.unique(manifest.corners.map(\.cornerID))
        let assets = Dictionary(uniqueKeysWithValues: manifest.assets.map { ($0.assetID, $0) })
        let declaredCorners = Dictionary(uniqueKeysWithValues: manifest.corners.map { ($0.cornerID, $0) })
        let sources = Dictionary(uniqueKeysWithValues: definition.sources.compactMap { s in s.assetID.map { ($0, s) } })
        var corners: [PDKProfileCorner] = []
        for id in definition.requiredCornerIDs.sorted() {
            guard let c = declaredCorners[id] else { throw .missingSelection(id) }
            corners.append(try PDKProfileCorner(cornerID: id, pvt: c.pvt))
        }
        var selections: [PDKProfileSelection] = []
        var roots: Set<String> = []
        for r in definition.requirements.sorted(by: { $0.requirementID < $1.requirementID }) {
            let contexts: [String?] = r.isShared ? [nil] : r.cornerIDs.sorted().map(Optional.some)
            for cornerID in contexts {
                var selected: [String] = []
                for id in r.assetIDs {
                    guard let asset = assets[id], let source = sources[id], asset.role == r.role else { throw .missingSelection(id) }
                    let locator: ArtifactLocator
                    do { locator = try asset.artifactLocator() } catch { throw .conflictingReference(id) }
                    guard PDKIdentityDescriptorPolicy.matches(locator, reference: source.reference),
                          asset.identityFindings(for: source.reference).isEmpty else { throw .conflictingReference(id) }
                    let mappings = manifest.crossViewMappings.filter { $0.view == r.view && $0.assetID == id }
                    if let cornerID {
                        guard let c = declaredCorners[cornerID] else { throw .missingSelection(cornerID) }
                        // Assets for another explicitly requested corner are not candidates here.
                        if !asset.cornerIDs.contains(cornerID) { continue }
                        // Manifest view keys are open names; the typed cross-view mapping owns view semantics.
                        guard c.assetIDs.contains(id),
                              c.viewMappings.values.contains(id),
                              mappings.contains(where: { $0.cornerIDs.contains(cornerID) }) else { throw .missingSelection(r.requirementID + ":" + cornerID) }
                    } else {
                        guard asset.cornerIDs.isEmpty,
                              mappings.contains(where: { $0.cornerIDs.isEmpty }) else { throw .missingSelection(r.requirementID) }
                    }
                    selected.append(id)
                    roots.insert(source.sourceKey)
                }
                guard !selected.isEmpty else { throw .missingSelection(r.requirementID) }
                guard r.allowsMultipleSources || selected.count == 1 else { throw .ambiguousSelection(r.requirementID) }
                selections.append(try PDKProfileSelection(requirementID: r.requirementID, cornerID: cornerID,
                    assetIDs: selected, sourceKeys: selected.compactMap { sources[$0]?.sourceKey }, selectedSection: r.selectedSection))
            }
        }
        var support: [String] = []
        for asset in manifest.assets where asset.required {
            guard let source = sources[asset.assetID] else { throw .missingSelection(asset.assetID) }
            let locator: ArtifactLocator
            do { locator = try asset.artifactLocator() } catch { throw .conflictingReference(asset.assetID) }
            guard PDKIdentityDescriptorPolicy.matches(locator, reference: source.reference),
                  asset.identityFindings(for: source.reference).isEmpty else { throw .conflictingReference(asset.assetID) }
            if !roots.contains(source.sourceKey) { support.append(source.sourceKey) }
            roots.insert(source.sourceKey)
        }
        self.definition = definition
        self.manifestReference = manifestReference
        self.corners = corners
        self.selections = selections
        self.roots = definition.sources.filter { roots.contains($0.sourceKey) }.sorted { $0.sourceKey < $1.sourceKey }
        self.mandatorySupportSourceKeys = support.sorted()
    }
}
