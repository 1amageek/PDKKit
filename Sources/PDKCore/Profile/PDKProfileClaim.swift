import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation

/// A serializable selection claim. Decoding never creates an admitted value.
public struct PDKProfileClaim: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public let definitionReference: ArtifactReference
    public let definition: PDKProfileDefinition
    public let manifestReference: ArtifactReference
    public let corners: [PDKProfileCorner]
    public let selections: [PDKProfileSelection]
    public let sourceClosure: [PDKProfileSource]
    public let dependencies: [PDKSourceDependency]
    public let mandatorySupportSourceKeys: [String]
    public let semanticSelectionDigest: ContentDigest
    private let storageReservations: [PDKAdmissionReservation]

    public init(definitionReference: ArtifactReference, plan: PDKProfilePlan,
                resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.temporary(String.self, capacity: plan.definition.sources.count)
        var keys: [String] = []; keys.reserveCapacity(plan.definition.sources.count)
        for source in plan.roots { try work.step(); _ = try work.insert(source.sourceKey, into: &keys) }
        var grew = true
        while grew {
            try work.step(); grew = false
            for edge in plan.definition.dependencies {
                try work.step()
                if try work.contains(keys, edge.parentSourceKey), try work.insert(edge.childSourceKey, into: &keys) { grew = true }
            }
        }
        try self.init(definitionReference: definitionReference, definition: plan.definition,
            manifestReference: plan.manifestReference, corners: plan.corners, selections: plan.selections,
            sourceClosure: work.filter(plan.definition.sources, { (source) throws(PDKProfileValueError) in try work.contains(keys, source.sourceKey) }),
            dependencies: work.filter(plan.definition.dependencies, { (edge) throws(PDKProfileValueError) in try work.contains(keys, edge.parentSourceKey) }),
            mandatorySupportSourceKeys: plan.mandatorySupportSourceKeys, resources: resources, inputReservations: plan.storageReservations)
    }

    private init(definitionReference: ArtifactReference, definition: PDKProfileDefinition,
        manifestReference: ArtifactReference, corners: [PDKProfileCorner], selections: [PDKProfileSelection],
        sourceClosure: [PDKProfileSource], dependencies: [PDKSourceDependency],
        mandatorySupportSourceKeys: [String], resources: (any PDKAdmissionResourceAccounting)?,
        inputReservations: [PDKAdmissionReservation] = []) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        try PDKProfileWire.reference(definitionReference, id: definition.profileID, resources: resources)
        guard definitionReference.descriptor.format == .json,
              try work.equal(manifestReference, definition.manifestReference) else { throw .conflictingReference(work.context(definition.profileID)) }
        let cornerIDs = try work.map(corners, { $0.cornerID })
        try work.unique(cornerIDs)
        guard try work.equal(work.sorted(cornerIDs, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) }), work.sorted(definition.requiredCornerIDs, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) })) else { throw .missingSelection("corners") }
        try work.unique(work.map(sourceClosure, { $0.sourceKey }))
        try work.unique(mandatorySupportSourceKeys)
        for source in sourceClosure {
            guard try work.contains(definition.sources, where: { (declared) throws(PDKProfileValueError) in try work.equal(declared, source) }) else { throw .conflictingReference(work.context(source.sourceKey)) }
        }
        for key in mandatorySupportSourceKeys {
            guard try work.contains(sourceClosure, where: { (source) throws(PDKProfileValueError) in try work.equal(source.sourceKey, key) }) else { throw .missingSelection("support") }
        }
        try work.temporary(SelectionContext.self, capacity: selections.count)
        try work.temporary(String.self, capacity: sourceClosure.count)
        var selectionKeys: [SelectionContext] = []; selectionKeys.reserveCapacity(selections.count)
        var roots: [String] = []; roots.reserveCapacity(sourceClosure.count)
        for key in mandatorySupportSourceKeys { try work.step(); _ = try work.insert(key, into: &roots) }
        for s in selections {
            try work.step()
            let key = SelectionContext(requirementID: s.requirementID, cornerID: s.cornerID)
            guard try !work.contains(selectionKeys, where: { (prior) throws(PDKProfileValueError) in
                guard try work.equal(prior.requirementID, key.requirementID) else { return false }
                return try work.equal(prior.cornerID, key.cornerID) }) else { throw .duplicateKey(work.context(s.requirementID)) }
            selectionKeys.append(key)
            guard let r = try work.first(definition.requirements, where: { (r) throws(PDKProfileValueError) in try work.equal(r.requirementID, s.requirementID) }),
                  try work.equal(r.selectedSection, s.selectedSection),
                  r.isShared ? s.cornerID == nil : s.cornerID != nil,
                  r.allowsMultipleSources || s.assetIDs.count == 1 else { throw .missingSelection(work.context(s.requirementID)) }
            if let corner = s.cornerID {
                guard try work.contains(r.cornerIDs, where: { (id) throws(PDKProfileValueError) in try work.equal(id, corner) }) else { throw .missingSelection(work.context(s.requirementID)) }
            }
            var priorAssetIndex: Int?
            for (index, asset) in s.assetIDs.enumerated() {
                try work.step()
                var found: Int?
                for (candidate, id) in r.assetIDs.enumerated() { try work.step(); if try work.equal(id, asset) { found = candidate; break } }
                guard let found, priorAssetIndex.map({ found > $0 }) ?? true else { throw .missingSelection(work.context(s.requirementID)) }
                priorAssetIndex = found
                let source = s.sourceKeys[index]
                guard let declared = try work.first(sourceClosure, where: { (candidate) throws(PDKProfileValueError) in try work.equal(candidate.sourceKey, source) }),
                      try work.equal(declared.assetID, asset) else { throw .conflictingReference(work.context(source)) }
                _ = try work.insert(source, into: &roots)
            }
        }
        for r in definition.requirements {
            try work.step()
            if r.isShared {
                guard try work.contains(selectionKeys, where: { (key) throws(PDKProfileValueError) in
                    guard key.cornerID == nil else { return false }
                    return try work.equal(key.requirementID, r.requirementID) }) else { throw .missingSelection(work.context(r.requirementID)) }
            } else {
                for corner in r.cornerIDs {
                    try work.step()
                    guard try work.contains(selectionKeys, where: { (key) throws(PDKProfileValueError) in
                        guard try work.equal(key.requirementID, r.requirementID) else { return false }
                        return try work.equal(key.cornerID, corner) }) else { throw .missingSelection(work.context(r.requirementID)) }
                }
            }
        }
        let expectedEdges = try work.filter(definition.dependencies, { (edge) throws(PDKProfileValueError) in try work.contains(sourceClosure, where: { (source) throws(PDKProfileValueError) in try work.equal(source.sourceKey, edge.parentSourceKey) }) })
        try work.step(UInt64(max(expectedEdges.count, dependencies.count)))
        guard dependencies.count == expectedEdges.count else { throw .noncanonicalEncoding("dependencies") }
        for index in dependencies.indices { guard try work.equal(dependencies[index], expectedEdges[index]) else { throw .noncanonicalEncoding("dependencies") } }
        try work.temporary(String.self, capacity: sourceClosure.count)
        var reachable: [String] = []; reachable.reserveCapacity(sourceClosure.count)
        for root in roots { try work.step(); reachable.append(root) }
        var grew = true
        while grew {
            try work.step(); grew = false
            for edge in dependencies {
                try work.step()
                if try work.contains(reachable, edge.parentSourceKey), try work.insert(edge.childSourceKey, into: &reachable) { grew = true }
            }
        }
        guard reachable.count == sourceClosure.count else { throw .missingSelection("source closure") }
        for source in sourceClosure { guard try work.contains(reachable, source.sourceKey) else { throw .missingSelection("source closure") } }
        var reservations = inputReservations
        if let r = try work.retained(PDKProfileCorner.self, capacity: corners.count) { reservations.append(r) }
        if let r = try work.retained(PDKProfileSelection.self, capacity: selections.count) { reservations.append(r) }
        if let r = try work.retained(PDKProfileSource.self, capacity: sourceClosure.count) { reservations.append(r) }
        if let r = try work.retained(String.self, capacity: mandatorySupportSourceKeys.count) { reservations.append(r) }
        self.definitionReference = definitionReference; self.definition = definition; self.manifestReference = manifestReference
        self.corners = try work.sorted(corners, ownedResult: true, by: { (lhs, rhs) throws(PDKProfileValueError) in try work.less(lhs.cornerID, rhs.cornerID) })
        self.selections = try work.sorted(selections, ownedResult: true, by: work.selectionLess)
        self.sourceClosure = try work.sorted(sourceClosure, ownedResult: true, by: { (lhs, rhs) throws(PDKProfileValueError) in try work.less(lhs.sourceKey, rhs.sourceKey) })
        if let r = try work.retained(PDKSourceDependency.self, capacity: dependencies.count) { reservations.append(r) }
        var ownedDependencies: [PDKSourceDependency] = []; ownedDependencies.reserveCapacity(dependencies.count)
        for edge in dependencies { try work.step(); ownedDependencies.append(edge) }
        self.dependencies = ownedDependencies
        self.mandatorySupportSourceKeys = try work.sorted(mandatorySupportSourceKeys, ownedResult: true, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) })
        self.storageReservations = reservations
        let codec = PDKProfileCanonicalEncoding()
        let buffer = try codec.buffer(definitionReference: definitionReference, definition: definition,
            corners: self.corners, selections: self.selections, sources: self.sourceClosure,
            dependencies: dependencies, mandatorySupportSourceKeys: self.mandatorySupportSourceKeys, resources: resources)
        self.semanticSelectionDigest = try codec.digest(buffer.bytes, resources: resources)
        withExtendedLifetime(buffer) {}
        try work.check()
    }

    public func canonicalBytes() throws(PDKProfileValueError) -> [UInt8] {
        // Runtime canonical hashing occurs within checked construction; exported bytes need caller-owned lifetime admission.
        try PDKProfileCanonicalEncoding().buffer(definitionReference: definitionReference, definition: definition,
            corners: corners, selections: selections, sources: sourceClosure, dependencies: dependencies,
            mandatorySupportSourceKeys: mandatorySupportSourceKeys).bytes
    }
    private struct SelectionContext: Hashable {
        let requirementID: String
        let cornerID: String?
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.definitionReference == rhs.definitionReference && lhs.definition == rhs.definition && lhs.manifestReference == rhs.manifestReference
            && lhs.corners == rhs.corners && lhs.selections == rhs.selections && lhs.sourceClosure == rhs.sourceClosure
            && lhs.dependencies == rhs.dependencies && lhs.mandatorySupportSourceKeys == rhs.mandatorySupportSourceKeys
            && lhs.semanticSelectionDigest == rhs.semanticSelectionDigest
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(definitionReference); hasher.combine(definition); hasher.combine(manifestReference); hasher.combine(corners)
        hasher.combine(selections); hasher.combine(sourceClosure); hasher.combine(dependencies)
        hasher.combine(mandatorySupportSourceKeys); hasher.combine(semanticSelectionDigest)
    }
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, definitionReference, definition, manifestReference, corners, selections,
             sourceClosure, dependencies, mandatorySupportSourceKeys, semanticSelectionDigest
    }
    public init(from decoder: Decoder) throws {
        try PDKProfileWire.check(decoder, fields: ["definitionReference", "definition", "manifestReference", "corners", "selections", "sourceClosure", "dependencies", "mandatorySupportSourceKeys", "semanticSelectionDigest"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(definitionReference: c.decode(ArtifactReference.self, forKey: .definitionReference),
            definition: c.decode(PDKProfileDefinition.self, forKey: .definition),
            manifestReference: c.decode(ArtifactReference.self, forKey: .manifestReference),
            corners: c.decode([PDKProfileCorner].self, forKey: .corners),
            selections: c.decode([PDKProfileSelection].self, forKey: .selections),
            sourceClosure: c.decode([PDKProfileSource].self, forKey: .sourceClosure),
            dependencies: c.decode([PDKSourceDependency].self, forKey: .dependencies),
            mandatorySupportSourceKeys: c.decode([String].self, forKey: .mandatorySupportSourceKeys), resources: PDKProfileWire.resources(decoder))
        guard try c.decode(ContentDigest.self, forKey: .semanticSelectionDigest) == semanticSelectionDigest else {
            throw PDKProfileValueError.noncanonicalEncoding("semanticSelectionDigest")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(definitionReference, forKey: .definitionReference); try c.encode(definition, forKey: .definition)
        try c.encode(manifestReference, forKey: .manifestReference); try c.encode(corners, forKey: .corners)
        try c.encode(selections, forKey: .selections); try c.encode(sourceClosure, forKey: .sourceClosure)
        try c.encode(dependencies, forKey: .dependencies); try c.encode(mandatorySupportSourceKeys, forKey: .mandatorySupportSourceKeys)
        try c.encode(semanticSelectionDigest, forKey: .semanticSelectionDigest)
    }
}
