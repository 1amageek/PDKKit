import Foundation
import Synchronization
import Testing
import CircuiteFoundation
import CircuiteFoundationFoundation
import CircuiteFoundationCrypto
@testable import PDKCore

@Suite struct ProfileValueTests {
    func reference(_ digit: String = "1", kind: String = "pdk.spice", role: String = "input", format: ArtifactFormat = .spice) throws -> ArtifactReference {
        try ArtifactReference(digest: ContentDigest(algorithm: .sha256, hexadecimalValue: String(repeating: digit, count: 64)),
            byteCount: 4, descriptor: ArtifactDescriptor(role: ArtifactRole(validatingRawValue: role), kind: ArtifactKind(rawValue: kind), format: format))
    }
    func fixture(temperature: Double = 25, extraSource: Bool = false, dependencies: Bool = false,
                 shared: Bool = false, multiple: Bool = false) throws -> (PDKProfileDefinition, PDKManifest, ArtifactReference) {
        let manifestRef = try reference("a", kind: "pdk.technology", format: .json)
        let source = try PDKProfileSource(sourceKey: "root", assetID: "model", reference: reference(), logicalRoutes: ["model.sp"])
        let r = try PDKViewRequirement(requirementID: "simulation", purposeID: "transient", view: .spice, role: .model,
            assetIDs: multiple ? ["model", "model2"] : ["model"], cornerIDs: shared ? [] : ["tt"], selectedSection: nil,
            isShared: shared, allowsMultipleSources: multiple, demandedFactKinds: ["devices", "dependencies"])
        let pvt = PDKPVTCondition(process: PDKProcessCorner(name: "typical", nominal: true), voltage: 1.0, temperatureCelsius: temperature)
        var sources = [source]
        var edges: [PDKSourceDependency] = []
        if extraSource || dependencies || multiple {
            sources.append(try PDKProfileSource(sourceKey: "child", assetID: multiple ? "model2" : nil, reference: reference("2"), logicalRoutes: ["child.sp"]))
        }
        if dependencies {
            edges.append(try PDKSourceDependency(parentSourceKey: "root", parentReference: reference(), statementByteOffset: 2,
                statementOrdinal: 1, directiveKind: "include", literalRoute: "child.sp", childSourceKey: "child", childReference: reference("2"),
                selectedSection: nil, preprocessingIdentity: "none", lexicalOrder: 1))
        }
        let definition = try PDKProfileDefinition(profileID: "demo", manifestReference: manifestRef, processID: "p", version: "1",
            requiredCornerIDs: shared ? [] : ["tt"], requirements: [r], sources: sources, orderedSearchRoutes: ["models"], dependencies: edges,
            inspectionPolicyIdentity: "policy.v1", initialPreprocessingIdentity: "environment.empty.v1")
        var assets = [try PDKAssetReference(assetID: "model", role: .model, path: "model.sp", kind: ArtifactKind(rawValue: "spice"), format: .spice,
            required: true, sha256: String(repeating: "1", count: 64), byteCount: 4, cornerIDs: shared ? [] : ["tt"])]
        var mappings = [PDKCrossViewMapping(mappingID: "spice", view: .spice, assetID: "model", cornerIDs: shared ? [] : ["tt"])]
        if multiple {
            assets.append(PDKAssetReference(assetID: "model2", role: .model, path: "child.sp", kind: try ArtifactKind(rawValue: "spice"), format: .spice, required: true))
            mappings.append(PDKCrossViewMapping(mappingID: "spice2", view: .spice, assetID: "model2"))
        }
        let manifest = PDKManifest(processID: "p", version: "1", assets: assets,
            corners: shared ? [] : [PDKCornerDefinition(cornerID: "tt", pvt: pvt, assetIDs: ["model"], viewMappings: ["spice": "model"])], crossViewMappings: mappings)
        return (definition, manifest, try reference("d", kind: "pdk.profile", format: .json))
    }
    func claim(_ f: (PDKProfileDefinition, PDKManifest, ArtifactReference)) throws -> PDKProfileClaim {
        try PDKProfileClaim(definitionReference: f.2, plan: PDKProfilePlan(definition: f.0, manifest: f.1, manifestReference: f.0.manifestReference))
    }

    @Test func missingAndEmptyCornerBindingsFail() throws {
        let f = try fixture()
        var manifest = f.1; manifest.corners[0].assetIDs = []
        #expect(throws: PDKProfileValueError.self) { try PDKProfilePlan(definition: f.0, manifest: manifest, manifestReference: f.0.manifestReference) }
        manifest = f.1; manifest.corners[0].viewMappings = [:]
        #expect(throws: PDKProfileValueError.self) { try PDKProfilePlan(definition: f.0, manifest: manifest, manifestReference: f.0.manifestReference) }
        manifest = f.1; manifest.assets[0].cornerIDs = []
        #expect(throws: PDKProfileValueError.self) { try PDKProfilePlan(definition: f.0, manifest: manifest, manifestReference: f.0.manifestReference) }
        manifest = f.1; manifest.crossViewMappings[0].cornerIDs = []
        #expect(throws: PDKProfileValueError.self) { try PDKProfilePlan(definition: f.0, manifest: manifest, manifestReference: f.0.manifestReference) }
        manifest = f.1; manifest.crossViewMappings[0].view = .liberty
        #expect(throws: PDKProfileValueError.self) { try PDKProfilePlan(definition: f.0, manifest: manifest, manifestReference: f.0.manifestReference) }
    }
    @Test func pvtFiniteAndExact() throws {
        let base = try claim(fixture())
        #expect(base.semanticSelectionDigest != (try claim(fixture(temperature: 26))).semanticSelectionDigest)
        for t in [Double.nan, .infinity, -273.15] {
            #expect(throws: PDKProfileValueError.self) { try claim(fixture(temperature: t)) }
        }
        #expect(try claim(fixture(temperature: -0.0)).canonicalBytes() == claim(fixture(temperature: 0.0)).canonicalBytes())
        let nominal = try PDKSourceTemperatureFact(kind: "modelNominalTemperature", temperatureCelsius: 27,
            sourceReference: reference(), evidenceIdentity: "tnom")
        #expect(nominal.temperatureCelsius == 27)
        #expect(throws: PDKProfileValueError.self) {
            try PDKSourcePVTFact(kind: "modelNominal", pvt: base.corners[0].pvt, sourceReference: reference(), evidenceIdentity: "tnom")
        }
        var f = try fixture(); f.1.corners[0].pvt.voltage = 0
        #expect(throws: PDKProfileValueError.self) { try claim(f) }
    }
    @Test func orderedMultiSourceSelection() throws {
        let f = try fixture(shared: true, multiple: true)
        let first = try claim(f)
        let r = f.0.requirements[0]
        let reverse = try PDKViewRequirement(requirementID: r.requirementID, purposeID: r.purposeID, view: r.view, role: r.role,
            assetIDs: r.assetIDs.reversed(), cornerIDs: [], selectedSection: nil, isShared: true, allowsMultipleSources: true, demandedFactKinds: r.demandedFactKinds)
        let d = try replacing(f.0, requirements: [reverse])
        let second = try claim((d, f.1, f.2))
        #expect(first.semanticSelectionDigest != second.semanticSelectionDigest)
        #expect(first.selections[0].assetIDs == ["model", "model2"])
        let singular = try PDKViewRequirement(requirementID: r.requirementID, purposeID: r.purposeID, view: r.view, role: r.role,
            assetIDs: r.assetIDs, cornerIDs: [], selectedSection: nil, isShared: true, allowsMultipleSources: false, demandedFactKinds: r.demandedFactKinds)
        #expect(throws: PDKProfileValueError.self) { try claim((replacing(f.0, requirements: [singular]), f.1, f.2)) }
    }
    func replacing(_ d: PDKProfileDefinition, requirements: [PDKViewRequirement]? = nil, sources: [PDKProfileSource]? = nil,
                   dependencies: [PDKSourceDependency]? = nil, initialPreprocessingIdentity: String? = nil) throws -> PDKProfileDefinition {
        try PDKProfileDefinition(profileID: d.profileID, manifestReference: d.manifestReference, processID: d.processID, version: d.version,
            requiredCornerIDs: d.requiredCornerIDs, requirements: requirements ?? d.requirements, sources: sources ?? d.sources,
            orderedSearchRoutes: d.orderedSearchRoutes, dependencies: dependencies ?? d.dependencies, inspectionPolicyIdentity: d.inspectionPolicyIdentity,
            initialPreprocessingIdentity: initialPreprocessingIdentity ?? d.initialPreprocessingIdentity)
    }
    @Test func exactDescriptorAndDependencyIdentity() throws {
        let f = try fixture(dependencies: true)
        let base = try claim(f)
        #expect(base.sourceClosure.count == 2)
        let relative = try PDKSourceDependency(parentSourceKey: "root", parentReference: reference(), statementByteOffset: 2,
            statementOrdinal: 1, directiveKind: "include", literalRoute: "../models/child.sp", childSourceKey: "child", childReference: reference("2"),
            selectedSection: nil, preprocessingIdentity: "none", lexicalOrder: 1)
        let nestedParent = try PDKProfileSource(sourceKey: "root", assetID: "model", reference: reference(), logicalRoutes: ["decks/root.sp"])
        let normalizedChild = try PDKProfileSource(sourceKey: "child", assetID: nil, reference: reference("2"), logicalRoutes: ["models/child.sp"])
        #expect(try replacing(f.0, sources: [nestedParent, normalizedChild], dependencies: [relative]).dependencies[0].literalRoute == "../models/child.sp")
        let descriptorAlias = try PDKProfileSource(sourceKey: "alias", assetID: nil, reference: reference("2", role: "custom"), logicalRoutes: ["alias.sp"])
        let aliasEdge = try PDKSourceDependency(parentSourceKey: "root", parentReference: reference(), statementByteOffset: 5,
            statementOrdinal: 2, directiveKind: "include", literalRoute: "alias.sp", childSourceKey: "alias", childReference: descriptorAlias.reference,
            selectedSection: nil, preprocessingIdentity: "none", lexicalOrder: 2)
        let aliased = try claim((replacing(f.0, sources: f.0.sources + [descriptorAlias], dependencies: f.0.dependencies + [aliasEdge]), f.1, f.2))
        #expect(aliased.sourceClosure.count == 3)
        #expect(aliased.sourceClosure.filter { $0.reference.id == descriptorAlias.reference.id }.count == 2)
        #expect(aliased.semanticSelectionDigest != base.semanticSelectionDigest)
        let occurrence = try PDKSourceDependency(parentSourceKey: "root", parentReference: reference(), statementByteOffset: 5,
            statementOrdinal: 2, directiveKind: "include", literalRoute: "child.sp", childSourceKey: "child", childReference: reference("2"),
            selectedSection: nil, preprocessingIdentity: "none", lexicalOrder: 2)
        let repeated = try replacing(f.0, dependencies: f.0.dependencies + [occurrence])
        #expect(try claim((repeated, f.1, f.2)).semanticSelectionDigest != base.semanticSelectionDigest)
        #expect(throws: PDKProfileValueError.self) { try replacing(f.0, dependencies: [occurrence] + f.0.dependencies) }
        let old = f.0.sources[1]
        let edited = try PDKProfileSource(sourceKey: old.sourceKey, assetID: nil, reference: reference("3"), logicalRoutes: old.logicalRoutes)
        #expect(throws: PDKProfileValueError.self) { try replacing(f.0, sources: [f.0.sources[0], edited]) }
        let e = f.0.dependencies[0]
        let newEdge = try PDKSourceDependency(parentSourceKey: e.parentSourceKey, parentReference: e.parentReference,
            statementByteOffset: e.statementByteOffset, statementOrdinal: e.statementOrdinal, directiveKind: e.directiveKind,
            literalRoute: e.literalRoute, childSourceKey: e.childSourceKey, childReference: edited.reference, selectedSection: nil,
            preprocessingIdentity: e.preprocessingIdentity, lexicalOrder: e.lexicalOrder)
        #expect(try claim((replacing(f.0, sources: [f.0.sources[0], edited], dependencies: [newEdge]), f.1, f.2)).semanticSelectionDigest != base.semanticSelectionDigest)
        let descriptorChange = try reference("1", role: "custom")
        #expect(descriptorChange.id == f.0.sources[0].reference.id)
        #expect(descriptorChange != f.0.sources[0].reference)
        let changedSource = try PDKProfileSource(sourceKey: "root", assetID: "model", reference: descriptorChange, logicalRoutes: ["model.sp"])
        #expect(throws: PDKProfileValueError.self) { try claim((replacing(f.0, sources: [changedSource, old], dependencies: []), f.1, f.2)) }
    }
    @Test func setOrderLocationAndCopies() throws {
        let f = try fixture(dependencies: true)
        let base = try claim(f)
        #expect(try claim((replacing(f.0, sources: f.0.sources.reversed()), f.1, f.2)).canonicalBytes() == base.canonicalBytes())
        var manifest = f.1; manifest.assets[0].path = "relocated/model.sp"
        #expect(try claim((f.0, manifest, f.2)).semanticSelectionDigest == base.semanticSelectionDigest)
        manifest.corners[0].pvt.temperatureCelsius = 90
        #expect(base.corners[0].pvt.temperatureCelsius == 25)
        #expect(try claim((f.0, manifest, f.2)).semanticSelectionDigest != base.semanticSelectionDigest)
    }
    @Test func strictWireAndClaimIdentity() throws {
        let codec = PDKProfileCodec(); let c = try claim(fixture())
        let bytes = try codec.encodeClaim(c)
        #expect(try codec.decodeClaim(bytes) == c)
        var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        object["schemaVersion"] = 0
        #expect(throws: PDKProfileValueError.self) { try codec.decodeClaim(JSONSerialization.data(withJSONObject: object)) }
        object["schemaVersion"] = 1; object["admitted"] = true
        #expect(throws: PDKProfileValueError.self) { try codec.decodeClaim(JSONSerialization.data(withJSONObject: object)) }
        object.removeValue(forKey: "admitted"); object["semanticSelectionDigest"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reference("9").digest))
        #expect(throws: PDKProfileValueError.self) { try codec.decodeClaim(JSONSerialization.data(withJSONObject: object)) }
        var definition = try #require(JSONSerialization.jsonObject(with: codec.encodeDefinition(c.definition)) as? [String: Any])
        definition.removeValue(forKey: "dependencies")
        #expect(throws: PDKProfileValueError.self) { try codec.decodeDefinition(JSONSerialization.data(withJSONObject: definition)) }
    }
    @Test func initialEnvironmentRequiresCurrentWireWithoutPolicyDefault() throws {
        let definition = try fixture().0
        let codec = PDKProfileCodec()
        let bytes = try codec.encodeDefinition(definition)
        #expect(try codec.decodeDefinition(bytes) == definition)
        let original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(original["schemaVersion"] as? Int == 2)
        #expect(definition.initialPreprocessingIdentity != definition.inspectionPolicyIdentity)
        for mutation in ["legacy", "missing", "empty", "unknown"] {
            var wire = original
            switch mutation {
            case "legacy": wire["schemaVersion"] = 1
            case "missing": wire.removeValue(forKey: "initialPreprocessingIdentity")
            case "empty": wire["initialPreprocessingIdentity"] = ""
            default: wire["initialEnvironment"] = "foreign"
            }
            #expect(throws: PDKProfileValueError.self) { try codec.decodeDefinition(JSONSerialization.data(withJSONObject: wire)) }
        }
        #expect(throws: PDKProfileValueError.self) { try replacing(definition, initialPreprocessingIdentity: "") }
    }
    @Test func initialEnvironmentCommitsThroughExactDefinitionWithoutChangingFraming() throws {
        let f = try fixture()
        let changed = try replacing(f.0, initialPreprocessingIdentity: "environment.choice.one.v1")
        let codec = PDKProfileCodec()
        func exactReference(_ definition: PDKProfileDefinition) throws -> ArtifactReference {
            let bytes = try codec.encodeDefinition(definition)
            let buffer = Array(bytes)
            let count = UInt64(buffer.count)
            let digest = try SHA256ContentDigester().digest(using: .sha256,
                limits: ContentDigestSessionLimits(maximumChunkByteCount: count,
                    maximumTotalByteCount: count, maximumUpdateCount: 1)) {
                    (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in
                try lease.update(buffer)
            }.digest
            return try ArtifactReference(digest: digest, byteCount: UInt64(bytes.count), descriptor: f.2.descriptor)
        }
        let a = try claim((f.0, f.1, exactReference(f.0)))
        let b = try claim((changed, f.1, exactReference(changed)))
        #expect(a.definitionReference != b.definitionReference)
        #expect(a.semanticSelectionDigest != b.semanticSelectionDigest)
        #expect(a.definition.inspectionPolicyIdentity == b.definition.inspectionPolicyIdentity)
        #expect(try codec.decodeClaim(codec.encodeClaim(b)) == b)
    }
    @Test func duplicateAndUnsafeRouteRefusal() throws {
        let f = try fixture()
        #expect(throws: PDKProfileValueError.self) { try replacing(f.0, sources: [f.0.sources[0], f.0.sources[0]]) }
        for route in ["../model.sp", "/model.sp", "a//b", "a/./b"] {
            #expect(throws: PDKProfileValueError.self) { try PDKProfileSource(sourceKey: "x", assetID: nil, reference: reference(), logicalRoutes: [route]) }
        }
    }
    @Test func mandatorySupportCannotBeDowngraded() throws {
        let f = try fixture(extraSource: true)
        var m = f.1
        m.assets.append(PDKAssetReference(assetID: "support", role: .other, path: "child.sp", kind: try ArtifactKind(rawValue: "spice"), format: .spice, required: true))
        #expect(throws: PDKProfileValueError.self) { try claim((f.0, m, f.2)) }
        let support = try PDKProfileSource(sourceKey: "child", assetID: "support", reference: reference("2"), logicalRoutes: ["child.sp"])
        let c = try claim((replacing(f.0, sources: [f.0.sources[0], support]), m, f.2))
        #expect(c.mandatorySupportSourceKeys == ["child"])
    }
    @Test func budgetAndReservationOwnership() throws {
        let limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64(10)) })
        let budget = try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: 100)
        #expect(try JSONDecoder().decode(PDKAdmissionBudget.self, from: JSONEncoder().encode(budget)) == budget)
        #expect(throws: PDKProfileValueError.self) { try PDKAdmissionBudget(limits: [:], maximumElapsedNanoseconds: 100) }
        #expect(throws: PDKAdmissionResourceError.self) { try PDKAdmissionCost(dimension: .readBytes, amount: 0) }
        let releases = Mutex(0)
        var copy: PDKAdmissionReservation?
        do {
            let original = PDKAdmissionReservation(cost: try PDKAdmissionCost(dimension: .liveOwnedBytes, amount: 5)) { releases.withLock { $0 += 1 } }
            copy = original
            #expect(releases.withLock { $0 } == 0)
        }
        #expect(copy?.cost.amount == 5)
        #expect(releases.withLock { $0 } == 0)
        copy = nil
        #expect(releases.withLock { $0 } == 1)
        #expect(PDKAdmissionResourceDimension.readBytes.isLiveCapacity == false)
        #expect(PDKAdmissionResourceDimension.liveOwnedBytes.isLiveCapacity)
    }
    @Test func goldenCanonicalEncodingV1() throws {
        let c = try claim(fixture(temperature: 0))
        // The complete independent vector is retained in CanonicalGoldenVector.swift.
        #expect(try c.canonicalBytes() == CanonicalGoldenVector.bytes)
        #expect(c.semanticSelectionDigest.hexadecimalValue == CanonicalGoldenVector.sha256)
    }
}
