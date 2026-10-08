import Testing
import CircuiteFoundation
import CircuiteFoundationFoundation
@testable import PDKCore

@Suite struct ProfileCatalogSelectionTests {
    private func select(_ definition: PDKProfileDefinition, _ manifest: PDKManifest,
                        resources: (any PDKAdmissionResourceAccounting)? = nil) throws -> PDKProfileCatalogSelection {
        try PDKProfileCatalogSelection(manifest: manifest, manifestReference: definition.manifestReference,
            requiredCornerIDs: definition.requiredCornerIDs, requirements: definition.requirements,
            sources: definition.sources, resources: resources)
    }

    @Test(arguments: [0, 1, 2]) func catalogAndPlanUseIdenticalSelections(_ variant: Int) throws {
        let fixture = try ProfileValueTests().fixture(shared: variant > 0, multiple: variant == 2)
        let catalog = try select(fixture.0, fixture.1)
        let plan = try PDKProfilePlan(definition: fixture.0, manifest: fixture.1,
            manifestReference: fixture.0.manifestReference)
        #expect(catalog.manifestReference == plan.manifestReference)
        #expect(catalog.corners == plan.corners)
        #expect(catalog.selections == plan.selections)
        #expect(catalog.roots == plan.roots)
        #expect(catalog.mandatorySupportSourceKeys == plan.mandatorySupportSourceKeys)
        #expect(catalog.selections[0].assetIDs == (variant == 2 ? ["model", "model2"] : ["model"]))
        #expect(catalog.selections[0].cornerID == (variant == 0 ? "tt" : nil))
    }

    @Test func multipleCornerContextsKeepSectionsAndStableOrder() throws {
        let f = try ProfileValueTests().fixture()
        var manifest = f.1
        var slow = manifest.corners[0]; slow.cornerID = "ss"; slow.pvt.process.name = "slow"
        manifest.corners.append(slow)
        manifest.assets[0].cornerIDs = ["tt", "ss"]
        manifest.crossViewMappings[0].cornerIDs = ["tt", "ss"]
        let r = f.0.requirements[0]
        let requirement = try PDKViewRequirement(requirementID: r.requirementID, purposeID: r.purposeID,
            view: r.view, role: r.role, assetIDs: r.assetIDs, cornerIDs: ["tt", "ss"],
            selectedSection: "typ", isShared: false, allowsMultipleSources: false,
            demandedFactKinds: r.demandedFactKinds)
        let catalog = try PDKProfileCatalogSelection(manifest: manifest, manifestReference: f.0.manifestReference,
            requiredCornerIDs: ["tt", "ss"], requirements: [requirement], sources: f.0.sources)
        #expect(catalog.corners.map(\.cornerID) == ["ss", "tt"])
        #expect(catalog.selections.map(\.cornerID) == ["ss", "tt"])
        #expect(catalog.selections.map(\.selectedSection) == ["typ", "typ"])
        #expect(catalog.roots == f.0.sources)
        let definition = try PDKProfileDefinition(profileID: f.0.profileID,
            manifestReference: f.0.manifestReference, processID: f.0.processID, version: f.0.version,
            requiredCornerIDs: ["tt", "ss"], requirements: [requirement], sources: f.0.sources,
            orderedSearchRoutes: f.0.orderedSearchRoutes, dependencies: [],
            inspectionPolicyIdentity: f.0.inspectionPolicyIdentity,
            initialPreprocessingIdentity: f.0.initialPreprocessingIdentity)
        let plan = try PDKProfilePlan(definition: definition, manifest: manifest,
            manifestReference: f.0.manifestReference)
        #expect(catalog.corners == plan.corners)
        #expect(catalog.selections == plan.selections)
    }

    @Test func catalogRejectsMissingRoleCornerMappingAndReference() throws {
        let f = try ProfileValueTests().fixture()
        var manifest = f.1
        manifest.corners = []
        #expect(throws: PDKProfileValueError.missingSelection("tt")) { try select(f.0, manifest) }
        manifest = f.1; manifest.assets[0].role = .technology
        #expect(throws: PDKProfileValueError.missingSelection("model")) { try select(f.0, manifest) }
        manifest = f.1; manifest.corners[0].viewMappings = [:]
        #expect(throws: PDKProfileValueError.missingSelection("simulation")) { try select(f.0, manifest) }
        manifest = f.1; manifest.assets[0].sha256 = String(repeating: "2", count: 64)
        #expect(throws: PDKProfileValueError.conflictingReference("model")) { try select(f.0, manifest) }
        manifest = f.1; manifest.schemaVersion = -1
        #expect(throws: PDKProfileValueError.conflictingReference("Catalog manifest")) { try select(f.0, manifest) }
        let wrongReference = try ProfileValueTests().reference()
        #expect(throws: PDKProfileValueError.conflictingReference("Catalog manifest")) {
            try PDKProfileCatalogSelection(manifest: f.1, manifestReference: wrongReference,
                requiredCornerIDs: f.0.requiredCornerIDs, requirements: f.0.requirements, sources: f.0.sources)
        }
        manifest = f.1; manifest.processID = "different"
        #expect(try select(f.0, manifest).roots == f.0.sources)
        #expect(throws: PDKProfileValueError.conflictingReference("demo")) {
            try PDKProfilePlan(definition: f.0, manifest: manifest, manifestReference: f.0.manifestReference)
        }
    }

    @Test func graphIndependentInputsAreCheckedBeforeSelection() throws {
        let f = try ProfileValueTests().fixture()
        func construct(corners: [String]? = nil, requirements: [PDKViewRequirement]? = nil,
                       sources: [PDKProfileSource]? = nil) throws -> PDKProfileCatalogSelection {
            try PDKProfileCatalogSelection(manifest: f.1, manifestReference: f.0.manifestReference,
                requiredCornerIDs: corners ?? f.0.requiredCornerIDs,
                requirements: requirements ?? f.0.requirements, sources: sources ?? f.0.sources)
        }
        #expect(throws: PDKProfileValueError.duplicateKey("tt")) { try construct(corners: ["tt", "tt"]) }
        #expect(throws: PDKProfileValueError.duplicateKey("simulation")) { try construct(requirements: f.0.requirements + f.0.requirements) }
        #expect(throws: PDKProfileValueError.duplicateKey("root")) { try construct(sources: f.0.sources + f.0.sources) }
        let alias = try PDKProfileSource(sourceKey: "alias", assetID: "model", reference: f.0.sources[0].reference, logicalRoutes: ["alias.sp"])
        #expect(throws: PDKProfileValueError.duplicateKey("model")) { try construct(sources: f.0.sources + [alias]) }
        #expect(throws: PDKProfileValueError.missingSelection("simulation")) { try construct(corners: []) }
        #expect(throws: PDKProfileValueError.missingSelection("Catalog selection")) { try construct(sources: []) }
        #expect(throws: PDKProfileValueError.missingSelection("Catalog selection")) { try construct(requirements: []) }
        let unbound = try PDKProfileSource(sourceKey: "root", assetID: nil, reference: f.0.sources[0].reference, logicalRoutes: ["model.sp"])
        #expect(throws: PDKProfileValueError.missingSelection("model")) { try construct(sources: [unbound]) }
    }

    @Test func ambiguityAndMandatorySupportRemainExact() throws {
        let helper = ProfileValueTests()
        let f = try helper.fixture(shared: true, multiple: true)
        let r = f.0.requirements[0]
        let singular = try PDKViewRequirement(requirementID: r.requirementID, purposeID: r.purposeID,
            view: r.view, role: r.role, assetIDs: r.assetIDs, cornerIDs: [], selectedSection: nil,
            isShared: true, allowsMultipleSources: false, demandedFactKinds: r.demandedFactKinds)
        #expect(throws: PDKProfileValueError.ambiguousSelection("simulation")) {
            try PDKProfileCatalogSelection(manifest: f.1, manifestReference: f.0.manifestReference,
                requiredCornerIDs: [], requirements: [singular], sources: f.0.sources)
        }
        let base = try helper.fixture()
        let source = try PDKProfileSource(sourceKey: "support", assetID: "supportAsset",
            reference: helper.reference("2"), logicalRoutes: ["support.sp"])
        var manifest = base.1
        manifest.assets.append(PDKAssetReference(assetID: "supportAsset", role: .model,
            path: "support.sp", kind: try ArtifactKind(rawValue: "spice"), format: .spice,
            required: true, sha256: String(repeating: "2", count: 64), byteCount: 4))
        #expect(throws: PDKProfileValueError.missingSelection("supportAsset")) { try select(base.0, manifest) }
        let definition = try helper.replacing(base.0, sources: base.0.sources + [source])
        let catalog = try select(definition, manifest)
        let plan = try PDKProfilePlan(definition: definition, manifest: manifest, manifestReference: definition.manifestReference)
        #expect(catalog.roots.map(\.sourceKey) == ["root", "support"])
        #expect(catalog.mandatorySupportSourceKeys == ["support"])
        #expect(catalog.roots == plan.roots)
        #expect(catalog.mandatorySupportSourceKeys == plan.mandatorySupportSourceKeys)
        manifest.assets[1].byteCount = 5
        #expect(throws: PDKProfileValueError.conflictingReference("supportAsset")) { try select(definition, manifest) }
    }

    @Test func sharedQuotaCancellationAndLastCopyLifetime() throws {
        let f = try ProfileValueTests().fixture()
        let owner = ProfileTestAccounting()
        var first: PDKProfileCatalogSelection? = try select(f.0, f.1, resources: owner)
        #expect(owner.used(.liveOwnedBytes) > 0)
        #expect(owner.used(.temporaryBytes) == 0)
        let charged = owner.used(.liveOwnedBytes)
        var last = first
        first = nil
        #expect(owner.used(.liveOwnedBytes) == charged)
        #expect(last?.roots == f.0.sources)
        last = nil
        #expect(owner.used(.liveOwnedBytes) == 0)
        let limited = ProfileTestAccounting(); limited.limit(.parserWork, to: 1)
        do {
            _ = try select(f.0, f.1, resources: limited)
            Issue.record("Catalog selection ignored the shared work quota")
        } catch let error as PDKProfileValueError {
            guard case .resource(.exhausted(dimension: .parserWork, limit: 1, attempted: _)) = error else { throw error }
        }
        #expect(limited.used(.liveOwnedBytes) == 0)
        #expect(limited.used(.temporaryBytes) == 0)
        let liveLimited = ProfileTestAccounting(); liveLimited.limit(.liveOwnedBytes, to: 1)
        do {
            _ = try select(f.0, f.1, resources: liveLimited)
            Issue.record("Catalog selection allocated beyond the live quota")
        } catch let error as PDKProfileValueError {
            guard case .resource(.exhausted(dimension: .liveOwnedBytes, limit: 1, attempted: _)) = error else { throw error }
        }
        #expect(liveLimited.used(.liveOwnedBytes) == 0)
        let cancelled = ProfileTestAccounting(); cancelled.failure = .cancelled
        #expect(throws: PDKProfileValueError.resource(.cancelled)) { try select(f.0, f.1, resources: cancelled) }
        #expect(cancelled.reservationCount == 0)
        let shared = ProfileTestAccounting()
        _ = try shared.reserve(PDKAdmissionCost(dimension: .parserWork, amount: 3))
        var catalog: PDKProfileCatalogSelection? = try select(f.0, f.1, resources: shared)
        #expect(shared.used(.parserWork) > 3)
        #expect(catalog?.selections.count == 1)
        catalog = nil
        #expect(shared.used(.liveOwnedBytes) == 0)
        let planOwner = ProfileTestAccounting()
        var plan: PDKProfilePlan? = try PDKProfilePlan(definition: f.0, manifest: f.1,
            manifestReference: f.0.manifestReference, resources: planOwner)
        var claim: PDKProfileClaim?
        do {
            let retainedPlan = try #require(plan)
            claim = try PDKProfileClaim(definitionReference: f.2, plan: retainedPlan, resources: planOwner)
        }
        plan = nil
        #expect(claim?.selections.count == 1)
        #expect(planOwner.used(.liveOwnedBytes) > 0)
        claim = nil
        #expect(planOwner.used(.liveOwnedBytes) == 0)
    }
}
