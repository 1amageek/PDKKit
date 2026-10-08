import CircuiteFoundation
import CircuiteFoundationFoundation

/// Checked catalog selection before a dependency graph exists; this does not authenticate content.
public struct PDKProfileCatalogSelection: Sendable, Hashable {
    public let manifestReference: ArtifactReference
    public let corners: [PDKProfileCorner]
    public let selections: [PDKProfileSelection]
    public let roots: [PDKProfileSource]
    public let mandatorySupportSourceKeys: [String]
    let storageReservations: [PDKAdmissionReservation]

    public init(manifest: PDKManifest, manifestReference: ArtifactReference,
                requiredCornerIDs: [String], requirements: [PDKViewRequirement],
                sources: [PDKProfileSource], resources: (any PDKAdmissionResourceAccounting)? = nil)
    throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try PDKProfileWire.reference(manifestReference, id: "Catalog manifest", resources: resources)
        guard manifest.schemaVersion == PDKManifest.currentSchemaVersion,
              manifestReference.descriptor.format == .json,
              try work.technologyKind(manifestReference.descriptor.kind) else {
            throw .conflictingReference("Catalog manifest")
        }
        try work.unique(requiredCornerIDs)
        try work.unique(work.map(requirements, { $0.requirementID }))
        try work.unique(work.map(sources, { $0.sourceKey }))
        try work.temporary(String.self, capacity: sources.count)
        var assetIDs: [String] = []; assetIDs.reserveCapacity(sources.count)
        for source in sources { try work.step(); if let id = source.assetID { assetIDs.append(id) } }
        try work.unique(assetIDs)
        guard !requirements.isEmpty, !sources.isEmpty else { throw .missingSelection("Catalog selection") }
        for requirement in requirements {
            try work.step()
            for corner in requirement.cornerIDs {
                guard try work.contains(requiredCornerIDs, corner) else {
                    throw .missingSelection(work.context(requirement.requirementID))
                }
            }
            for asset in requirement.assetIDs {
                guard try work.contains(assetIDs, asset) else { throw .missingSelection(work.context(asset)) }
            }
        }
        try work.unique(work.map(manifest.assets, { $0.assetID }))
        try work.unique(work.map(manifest.corners, { $0.cornerID }))
        var reservations: [PDKAdmissionReservation] = []
        if let r = try work.retained(PDKProfileCorner.self, capacity: requiredCornerIDs.count) { reservations.append(r) }
        var corners: [PDKProfileCorner] = []; corners.reserveCapacity(requiredCornerIDs.count)
        for id in try work.sorted(requiredCornerIDs, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) }) {
            try work.step()
            guard let c = try work.first(manifest.corners, where: { (c) throws(PDKProfileValueError) in try work.equal(c.cornerID, id) }) else { throw .missingSelection(work.context(id)) }
            corners.append(try PDKProfileCorner(cornerID: id, pvt: c.pvt, resources: resources))
        }
        var selectionCapacity = 0
        for r in requirements {
            try work.step()
            let (next, overflow) = selectionCapacity.addingReportingOverflow(r.isShared ? 1 : r.cornerIDs.count)
            guard !overflow else { throw .resource(.arithmeticOverflow(.liveOwnedBytes)) }; selectionCapacity = next
        }
        if let r = try work.retained(PDKProfileSelection.self, capacity: selectionCapacity) { reservations.append(r) }
        if let r = try work.retained(PDKProfileSource.self, capacity: sources.count) { reservations.append(r) }
        try work.temporary(String.self, capacity: manifest.assets.count)
        try work.temporary(String.self, capacity: sources.count)
        var selections: [PDKProfileSelection] = []; selections.reserveCapacity(selectionCapacity)
        var rootKeys: [String] = []; rootKeys.reserveCapacity(sources.count)
        for r in try work.sorted(requirements, by: { (lhs, rhs) throws(PDKProfileValueError) in try work.less(lhs.requirementID, rhs.requirementID) }) {
            try work.step()
            if r.isShared { try work.temporary(Optional<String>.self, capacity: 1) }
            let contexts: [String?] = r.isShared ? [nil] : try work.map(work.sorted(r.cornerIDs, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) }), Optional.some)
            for cornerID in contexts {
                try work.step()
                if let charge = try work.retained(String.self, capacity: r.assetIDs.count) { reservations.append(charge) }
                if let charge = try work.retained(String.self, capacity: r.assetIDs.count) { reservations.append(charge) }
                var selected: [String] = []; selected.reserveCapacity(r.assetIDs.count)
                var selectedKeys: [String] = []; selectedKeys.reserveCapacity(r.assetIDs.count)
                for id in r.assetIDs {
                    try work.step()
                    guard let asset = try work.first(manifest.assets, where: { (asset) throws(PDKProfileValueError) in try work.equal(asset.assetID, id) }),
                          let source = try work.first(sources, where: { (source) throws(PDKProfileValueError) in try work.equal(source.assetID, id) }), asset.role == r.role else { throw .missingSelection(work.context(id)) }
                    guard try work.matches(asset, reference: source.reference) else { throw .conflictingReference(work.context(id)) }
                    if let cornerID {
                        guard let c = try work.first(manifest.corners, where: { (c) throws(PDKProfileValueError) in try work.equal(c.cornerID, cornerID) }) else { throw .missingSelection(work.context(cornerID)) }
                        if try !work.contains(asset.cornerIDs, where: { (id) throws(PDKProfileValueError) in try work.equal(id, cornerID) }) { continue }
                        // Manifest view keys are open names; typed cross-view mapping owns view semantics.
                        guard try work.contains(c.assetIDs, where: { (candidate) throws(PDKProfileValueError) in try work.equal(candidate, id) }) else { throw .missingSelection(work.context(r.requirementID)) }
                        var mapped = false
                        for value in c.viewMappings.values { try work.step(); if try work.equal(value, id) { mapped = true; break } }
                        guard mapped else { throw .missingSelection(work.context(r.requirementID)) }
                        var crossMapped = false
                        for mapping in manifest.crossViewMappings {
                            try work.step()
                            if mapping.view == r.view, try work.equal(mapping.assetID, id),
                               try work.contains(mapping.cornerIDs, where: { (id) throws(PDKProfileValueError) in try work.equal(id, cornerID) }) { crossMapped = true; break }
                        }
                        guard crossMapped else { throw .missingSelection(work.context(r.requirementID)) }
                    } else {
                        guard asset.cornerIDs.isEmpty,
                              try work.contains(manifest.crossViewMappings, where: { (mapping) throws(PDKProfileValueError) in
                                  guard mapping.view == r.view, mapping.cornerIDs.isEmpty else { return false }
                                  return try work.equal(mapping.assetID, id) }) else { throw .missingSelection(work.context(r.requirementID)) }
                    }
                    selected.append(id); selectedKeys.append(source.sourceKey); _ = try work.insert(source.sourceKey, into: &rootKeys)
                }
                guard !selected.isEmpty else { throw .missingSelection(work.context(r.requirementID)) }
                guard r.allowsMultipleSources || selected.count == 1 else { throw .ambiguousSelection(work.context(r.requirementID)) }
                selections.append(try PDKProfileSelection(requirementID: r.requirementID, cornerID: cornerID,
                    assetIDs: selected, sourceKeys: selectedKeys, selectedSection: r.selectedSection, resources: resources))
            }
        }
        var support: [String] = []; support.reserveCapacity(manifest.assets.count)
        for asset in manifest.assets {
            try work.step()
            guard asset.required else { continue }
            guard let source = try work.first(sources, where: { (source) throws(PDKProfileValueError) in try work.equal(source.assetID, asset.assetID) }) else { throw .missingSelection(work.context(asset.assetID)) }
            guard try work.matches(asset, reference: source.reference) else { throw .conflictingReference(work.context(asset.assetID)) }
            if try !work.contains(rootKeys, source.sourceKey) { support.append(source.sourceKey) }
            _ = try work.insert(source.sourceKey, into: &rootKeys)
        }
        self.manifestReference = manifestReference; self.corners = corners; self.selections = selections
        self.roots = try work.sorted(work.filter(sources, { (source) throws(PDKProfileValueError) in try work.contains(rootKeys, source.sourceKey) }), ownedResult: true, by: { (lhs, rhs) throws(PDKProfileValueError) in try work.less(lhs.sourceKey, rhs.sourceKey) })
        if let r = try work.retained(String.self, capacity: support.count) { reservations.append(r) }
        self.mandatorySupportSourceKeys = try work.sorted(support, ownedResult: true, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) })
        self.storageReservations = reservations
        try work.check()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.manifestReference == rhs.manifestReference && lhs.corners == rhs.corners
            && lhs.selections == rhs.selections && lhs.roots == rhs.roots
            && lhs.mandatorySupportSourceKeys == rhs.mandatorySupportSourceKeys
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(manifestReference); hasher.combine(corners); hasher.combine(selections)
        hasher.combine(roots); hasher.combine(mandatorySupportSourceKeys)
    }
}
