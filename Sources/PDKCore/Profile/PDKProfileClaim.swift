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

    public init(definitionReference: ArtifactReference, plan: PDKProfilePlan) throws(PDKProfileValueError) {
        var keys = Set(plan.roots.map(\.sourceKey))
        var grew = true
        while grew {
            grew = false
            for edge in plan.definition.dependencies where keys.contains(edge.parentSourceKey) {
                if keys.insert(edge.childSourceKey).inserted { grew = true }
            }
        }
        try self.init(definitionReference: definitionReference, definition: plan.definition,
            manifestReference: plan.manifestReference, corners: plan.corners, selections: plan.selections,
            sourceClosure: plan.definition.sources.filter { keys.contains($0.sourceKey) },
            dependencies: plan.definition.dependencies.filter { keys.contains($0.parentSourceKey) },
            mandatorySupportSourceKeys: plan.mandatorySupportSourceKeys)
    }

    private init(definitionReference: ArtifactReference, definition: PDKProfileDefinition,
        manifestReference: ArtifactReference, corners: [PDKProfileCorner], selections: [PDKProfileSelection],
        sourceClosure: [PDKProfileSource], dependencies: [PDKSourceDependency],
        mandatorySupportSourceKeys: [String]) throws(PDKProfileValueError) {
        try PDKProfileWire.reference(definitionReference, id: definition.profileID)
        guard definitionReference.descriptor.format == .json,
              manifestReference == definition.manifestReference else { throw PDKProfileValueError.conflictingReference(definition.profileID) }
        try PDKProfileWire.unique(corners.map(\.cornerID))
        guard Set(corners.map(\.cornerID)) == Set(definition.requiredCornerIDs) else { throw PDKProfileValueError.missingSelection("corners") }
        try PDKProfileWire.unique(sourceClosure.map(\.sourceKey))
        try PDKProfileWire.unique(mandatorySupportSourceKeys)
        let table = Dictionary(uniqueKeysWithValues: sourceClosure.map { ($0.sourceKey, $0) })
        for source in sourceClosure where !definition.sources.contains(source) { throw PDKProfileValueError.conflictingReference(source.sourceKey) }
        guard Set(mandatorySupportSourceKeys).isSubset(of: Set(table.keys)) else { throw PDKProfileValueError.missingSelection("support") }
        var selectionKeys: Set<[String]> = []
        var roots = Set(mandatorySupportSourceKeys)
        for s in selections {
            let key = [s.requirementID, s.cornerID ?? ""]
            guard selectionKeys.insert(key).inserted else { throw PDKProfileValueError.duplicateKey(s.requirementID) }
            guard let r = definition.requirements.first(where: { $0.requirementID == s.requirementID }),
                  r.selectedSection == s.selectedSection,
                  r.isShared ? s.cornerID == nil : s.cornerID.map(r.cornerIDs.contains) == true,
                  r.allowsMultipleSources || s.assetIDs.count == 1,
                  Set(s.assetIDs).isSubset(of: Set(r.assetIDs)),
                  s.assetIDs == r.assetIDs.filter({ s.assetIDs.contains($0) }) else { throw PDKProfileValueError.missingSelection(s.requirementID) }
            for (asset, source) in zip(s.assetIDs, s.sourceKeys) {
                guard table[source]?.assetID == asset else { throw PDKProfileValueError.conflictingReference(source) }
                roots.insert(source)
            }
        }
        for r in definition.requirements {
            let contexts: [String?] = r.isShared ? [nil] : r.cornerIDs.map(Optional.some)
            for c in contexts where !selectionKeys.contains([r.requirementID, c ?? ""]) { throw PDKProfileValueError.missingSelection(r.requirementID) }
        }
        let expectedEdges = definition.dependencies.filter { table[$0.parentSourceKey] != nil }
        guard dependencies == expectedEdges else { throw PDKProfileValueError.noncanonicalEncoding("dependencies") }
        var reachable = roots
        var grew = true
        while grew {
            grew = false
            for e in dependencies where reachable.contains(e.parentSourceKey) {
                if reachable.insert(e.childSourceKey).inserted { grew = true }
            }
        }
        guard reachable == Set(table.keys) else { throw PDKProfileValueError.missingSelection("source closure") }
        self.definitionReference = definitionReference; self.definition = definition
        self.manifestReference = manifestReference
        self.corners = corners.sorted { $0.cornerID < $1.cornerID }
        self.selections = selections.sorted { ($0.requirementID, $0.cornerID ?? "") < ($1.requirementID, $1.cornerID ?? "") }
        self.sourceClosure = sourceClosure.sorted { $0.sourceKey < $1.sourceKey }
        self.dependencies = dependencies
        self.mandatorySupportSourceKeys = mandatorySupportSourceKeys.sorted()
        let codec = PDKProfileCanonicalEncoding()
        do {
            self.semanticSelectionDigest = try codec.digest(codec.bytes(definitionReference: definitionReference,
            definition: definition, corners: self.corners, selections: self.selections, sources: self.sourceClosure,
            dependencies: dependencies, mandatorySupportSourceKeys: self.mandatorySupportSourceKeys))
        } catch { throw .noncanonicalEncoding("Digest failed: " + String(describing: error)) }
    }

    public func canonicalBytes() -> [UInt8] {
        PDKProfileCanonicalEncoding().bytes(definitionReference: definitionReference, definition: definition,
            corners: corners, selections: selections, sources: sourceClosure, dependencies: dependencies,
            mandatorySupportSourceKeys: mandatorySupportSourceKeys)
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
            mandatorySupportSourceKeys: c.decode([String].self, forKey: .mandatorySupportSourceKeys))
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
