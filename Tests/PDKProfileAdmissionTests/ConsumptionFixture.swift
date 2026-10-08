import CircuiteFoundation
import Foundation
import PDKCore
@testable import PDKProfileAdmission
import PDKSourceCapture

struct ConsumptionFixture {
    enum Kind: Equatable { case ordinary, multiCorner, mapped }
    let base: AdmissionFixture
    let request: PDKProfileAdmissionRequest
    let edges: [PDKSourceDependency]
    let kind: Kind
    static func make(_ kind: Kind) async throws -> Self {
        let base = try await AdmissionFixture.make(graph: kind == .multiCorner ? .nested : .leaf,
            support: true, corner: kind == .multiCorner, demandPVT: kind == .multiCorner)
        if kind == .ordinary { return .init(base: base, request: base.request, edges: [], kind: kind) }
        var manifest = base.manifest
        let cornerIDs = kind == .multiCorner ? ["tt", "ss"] : []
        var edges = base.definition.dependencies
        if kind == .multiCorner {
            var corner = manifest.corners[0]; corner.cornerID = "ss"
            corner.pvt.process = .init(name: "slow", nominal: false); corner.pvt.voltage = 0.9
            manifest.corners.append(corner); manifest.assets[0].cornerIDs = cornerIDs
            manifest.crossViewMappings[0].cornerIDs = cornerIDs
            let edge = edges[0]
            edges.append(try .init(parentSourceKey: edge.parentSourceKey, parentReference: edge.parentReference,
                statementByteOffset: edge.statementByteOffset, statementOrdinal: edge.statementOrdinal,
                directiveKind: edge.directiveKind, literalRoute: edge.literalRoute,
                childSourceKey: edge.childSourceKey, childReference: edge.childReference,
                selectedSection: edge.selectedSection, preprocessingIdentity: edge.preprocessingIdentity, lexicalOrder: 2))
        } else {
            manifest.layers = [.init(layerID: "metal", name: "M1", number: 1, purpose: .drawing)]
            manifest.devices = [.init(deviceID: "mos", modelName: "m", terminals: [
                .init(name: "d", role: .other, order: 0), .init(name: "g", role: .input, order: 1),
                .init(name: "s", role: .ground, order: 2), .init(name: "b", role: .bulk, order: 3)])]
            manifest.crossViewMappings[0].layerIDs = ["metal"]; manifest.crossViewMappings[0].deviceIDs = ["mos"]
        }
        let availability = base.request
        func write(_ bytes: Data, binding: PDKProfileExactBinding) async throws -> ArtifactReference {
            try bytes.write(to: base.root.appending(path: binding.relativePath.segments.joined(separator: "/")))
            let resources = LocalPDKAdmissionResources(budget: availability.budget); defer { resources.close() }
            return try await LocalPDKBoundedSourceCapturer().discover(descriptor: binding.reference.descriptor,
                rootURL: base.root, rootID: binding.rootID, relativePath: binding.relativePath,
                budget: binding.budget, resources: resources).reference
        }
        let manifestRef = try await write(PDKManifestCodec.encode(manifest), binding: availability.manifest)
        let old = base.definition.requirements[0]
        let requirement = try PDKViewRequirement(requirementID: old.requirementID, purposeID: old.purposeID, view: old.view,
            role: old.role, assetIDs: old.assetIDs, cornerIDs: cornerIDs, selectedSection: old.selectedSection,
            isShared: cornerIDs.isEmpty, allowsMultipleSources: old.allowsMultipleSources, demandedFactKinds: old.demandedFactKinds)
        let definition = try PDKProfileDefinition(profileID: base.definition.profileID, manifestReference: manifestRef,
            processID: base.definition.processID, version: base.definition.version, requiredCornerIDs: cornerIDs,
            requirements: [requirement], sources: base.definition.sources, orderedSearchRoutes: base.definition.orderedSearchRoutes,
            dependencies: edges, inspectionPolicyIdentity: base.definition.inspectionPolicyIdentity,
            initialPreprocessingIdentity: base.definition.initialPreprocessingIdentity)
        let definitionRef = try await write(PDKProfileCodec().encodeDefinition(definition), binding: availability.definition)
        let request = PDKProfileAdmissionRequest(definition: .init(reference: definitionRef, rootID: availability.definition.rootID,
            relativePath: availability.definition.relativePath, budget: availability.definition.budget),
            manifest: .init(reference: manifestRef, rootID: availability.manifest.rootID,
                relativePath: availability.manifest.relativePath, budget: availability.manifest.budget),
            roots: availability.roots, sources: availability.sources, budget: availability.budget,
            inspectionPolicyIdentity: availability.inspectionPolicyIdentity)
        return .init(base: base, request: request, edges: edges, kind: kind)
    }
    func admit(capture: AdmissionCaptureProbe = .init()) async throws -> AdmittedPDKProfile {
        let inspector = ConsumptionInspector(edges: edges, kind: kind)
        let registration = try PDKProfileInspectorRegistration(format: .spice, parserIdentity: "fixture.parser",
            policyIdentity: "policy.v1", inspector: inspector)
        return try await LocalPDKProfileAdmitter(inspectors: [registration], capture: capture).admit(request)
    }
    func cleanup() { base.cleanup() }
}

private struct ConsumptionInspector: PDKProfileSourceInspecting {
    let edges: [PDKSourceDependency]
    let kind: ConsumptionFixture.Kind
    func inspect(_ request: PDKProfileSourceInspectionRequest, dependencies: any PDKProfileDependencyResolving,
                 resources: any PDKAdmissionResourceAccounting) async throws(PDKProfileInspectionError) -> PDKProfileSourceFacts {
        let work = PDKAdmissionWork(resources: resources)
        let selectionLease: PDKAdmissionReservation?
        var selected = edges
        do throws(PDKProfileAdmissionError) {
            if kind == .multiCorner {
                selectionLease = try work.capacity(PDKSourceDependency.self, edges.count, dimension: .temporaryBytes)
                selected = []; selected.reserveCapacity(edges.count)
                for edge in edges {
                    try work.step()
                    if edge.lexicalOrder == (request.corner?.cornerID == "tt" ? 2 : 1) { selected.append(edge) }
                }
            } else { selectionLease = nil }
        } catch { if case .resource(let error) = error { throw .resource(error) }; throw .unsupportedSemantics }
        defer { withExtendedLifetime(selectionLease) {} }
        let facts = try await AdmissionScriptInspector(edges: selected).inspect(request, dependencies: dependencies, resources: resources)
        if kind != .mapped || request.input.sourceKey != "root" { return facts }
        do throws(PDKProfileAdmissionError) {
            let lease = try work.capacity(PDKProfileMappingFact.self, 4, dimension: .temporaryBytes)
            let terminals = try work.capacity(String.self, 4, dimension: .temporaryBytes)
            defer { withExtendedLifetime(lease) {}; withExtendedLifetime(terminals) {} }
            let mappings = [PDKProfileMappingFact(input: request.input, factKind: "devices", name: "m", terminals: ["d", "g", "s", "b"]),
                PDKProfileMappingFact(input: request.input, factKind: "layers", name: "M1", layerNumber: 1, layerPurpose: .drawing),
                PDKProfileMappingFact(input: request.input, factKind: "devices", name: "unrequested"),
                PDKProfileMappingFact(input: request.input, factKind: "layers", name: "partial", layerNumber: 9)]
            do { return try PDKProfileSourceFacts(input: facts.input, parserIdentity: facts.parserIdentity, policyIdentity: facts.policyIdentity,
                mappings: mappings, pvt: facts.pvt, temperatures: facts.temperatures, coverage: facts.coverage, events: facts.events,
                unsupportedFactKinds: [], lostFactKinds: [], resources: resources) }
            catch { if case .resource(let error) = error { throw .resource(error) }; throw .unsupportedSemantics }
        } catch { if case .resource(let error) = error { throw .resource(error) }; throw .unsupportedSemantics }
    }
}
