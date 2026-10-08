import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import PDKCore
import PDKDiscovery
@testable import PDKProfileAdmission
import PDKSourceCapture
import Synchronization
import Testing

struct AdmissionFixture {
    enum Graph: Equatable { case leaf, nested, repeated, cycle, inactive }
    let root: URL
    let request: PDKProfileAdmissionRequest
    let definition: PDKProfileDefinition
    let manifest: PDKManifest
    let rootReference: ArtifactReference
    let childReference: ArtifactReference?
    let expectedReadBytes: UInt64
    static func make(graph: Graph = .leaf, support: Bool = false, alias: Bool = false,
                     corner: Bool = false, demandPVT: Bool = false) async throws -> Self {
        let root = FileManager.default.temporaryDirectory.appending(path: "pdk-admission-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let rootID = try ArtifactRootID(rawValue: UUID().uuidString)
        let access = try ArtifactAccessBudget(maximumPageByteCount: 4096, maximumTotalByteCount: 10_000_000,
            maximumPageCount: 10_000, maximumWorkUnitCount: 10_000_000, maximumDurationNanoseconds: 10_000_000_000)
        let limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64(100_000_000)) })
        let budget = try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: 10_000_000_000)
        func write(_ bytes: Data, _ path: String, kind: String, format: ArtifactFormat = .spice) async throws -> ArtifactReference {
            try bytes.write(to: root.appending(path: path))
            let resources = LocalPDKAdmissionResources(budget: budget); defer { resources.close() }
            return try await LocalPDKBoundedSourceCapturer().discover(
                descriptor: ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: kind), format: format),
                rootURL: root, rootID: rootID, relativePath: ArtifactRelativePath(segments: [path]), budget: access, resources: resources).reference
        }
        let rootRef = try await write(Data("root model source\n".utf8), "root.sp", kind: "pdk.spice")
        var sources = [try PDKProfileSource(sourceKey: "root", assetID: "model", reference: rootRef, logicalRoutes: ["root.sp"])]
        var bindings = [PDKProfileSourceBinding(sourceKey: "root", logicalRoute: "root.sp", rootID: rootID,
            relativePath: try ArtifactRelativePath(segments: ["root.sp"]), budget: access)]
        var edges: [PDKSourceDependency] = []
        var child: ArtifactReference?
        if graph != .leaf {
            let ref = try await write(Data("child source data\n".utf8), "child.sp", kind: "pdk.spice")
            child = ref
            sources.append(try PDKProfileSource(sourceKey: "child", assetID: nil, reference: ref, logicalRoutes: ["child.sp"]))
            bindings.append(PDKProfileSourceBinding(sourceKey: "child", logicalRoute: "child.sp", rootID: rootID,
                relativePath: try ArtifactRelativePath(segments: ["child.sp"]), budget: access))
            edges.append(try PDKSourceDependency(parentSourceKey: "root", parentReference: rootRef, statementByteOffset: 1,
                statementOrdinal: 1, directiveKind: "include", literalRoute: "child.sp", childSourceKey: "child", childReference: ref,
                selectedSection: nil, preprocessingIdentity: "policy.v1", lexicalOrder: 1))
            if graph == .repeated {
                edges.append(try PDKSourceDependency(parentSourceKey: "root", parentReference: rootRef, statementByteOffset: 2,
                    statementOrdinal: 2, directiveKind: "include", literalRoute: "child.sp", childSourceKey: "child", childReference: ref,
                    selectedSection: nil, preprocessingIdentity: "policy.v1", lexicalOrder: 2))
            }
            if graph == .cycle {
                edges.append(try PDKSourceDependency(parentSourceKey: "child", parentReference: ref, statementByteOffset: 1,
                    statementOrdinal: 1, directiveKind: "include", literalRoute: "root.sp", childSourceKey: "root", childReference: rootRef,
                    selectedSection: nil, preprocessingIdentity: "policy.v1", lexicalOrder: 2))
            }
        }
        let pvt = PDKPVTCondition(process: PDKProcessCorner(name: "typical", nominal: true), voltage: 1, temperatureCelsius: 25)
        let cornerIDs = corner ? ["tt"] : []
        var assets = [PDKAssetReference(assetID: "model", role: .model, path: "root.sp", kind: try ArtifactKind(rawValue: "spice"),
            format: .spice, required: true, sha256: rootRef.digest.hexadecimalValue, byteCount: Int64(rootRef.byteCount), cornerIDs: cornerIDs)]
        var mappings = [PDKCrossViewMapping(mappingID: "spice", view: .spice, assetID: "model", logicalNames: ["m"], cornerIDs: cornerIDs)]
        var requirements = [try PDKViewRequirement(requirementID: "simulation", purposeID: "transient", view: .spice, role: .model,
            assetIDs: ["model"], cornerIDs: cornerIDs, selectedSection: nil, isShared: !corner,
            allowsMultipleSources: false, demandedFactKinds: demandPVT ? ["devices", "sourcePVT"] : ["devices"])]
        var extraRead: UInt64 = 0
        if support {
            let ref = try await write(Data("required support\n".utf8), "support.sp", kind: "pdk.spice")
            extraRead += ref.byteCount
            sources.append(try PDKProfileSource(sourceKey: "support", assetID: "support", reference: ref, logicalRoutes: ["support.sp"]))
            bindings.append(PDKProfileSourceBinding(sourceKey: "support", logicalRoute: "support.sp", rootID: rootID,
                relativePath: try ArtifactRelativePath(segments: ["support.sp"]), budget: access))
            assets.append(PDKAssetReference(assetID: "support", role: .model, path: "support.sp", kind: try ArtifactKind(rawValue: "spice"), format: .spice,
                required: true, sha256: ref.digest.hexadecimalValue, byteCount: Int64(ref.byteCount)))
        }
        if alias {
            let ref = try ArtifactReference(digest: rootRef.digest, byteCount: rootRef.byteCount,
                descriptor: ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: "pdk.model"), format: .spice))
            sources.append(try PDKProfileSource(sourceKey: "alias", assetID: "alias", reference: ref, logicalRoutes: ["alias.sp"]))
            bindings.append(PDKProfileSourceBinding(sourceKey: "alias", logicalRoute: "alias.sp", rootID: rootID,
                relativePath: try ArtifactRelativePath(segments: ["root.sp"]), budget: access))
            assets.append(PDKAssetReference(assetID: "alias", role: .model, path: "alias.sp", kind: try ArtifactKind(rawValue: "model"), format: .spice,
                required: true, sha256: ref.digest.hexadecimalValue, byteCount: Int64(ref.byteCount), cornerIDs: cornerIDs))
            mappings.append(PDKCrossViewMapping(mappingID: "alias", view: .spice, assetID: "alias", logicalNames: ["m"], cornerIDs: cornerIDs))
            requirements.append(try PDKViewRequirement(requirementID: "alias", purposeID: "transient", view: .spice, role: .model,
                assetIDs: ["alias"], cornerIDs: cornerIDs, selectedSection: nil, isShared: !corner, allowsMultipleSources: false, demandedFactKinds: ["devices"]))
        }
        let manifest = PDKManifest(processID: "p", version: "1", assets: assets,
            corners: corner ? [PDKCornerDefinition(cornerID: "tt", pvt: pvt, assetIDs: ["model"], viewMappings: ["spice": "model"])] : [], crossViewMappings: mappings)
        let manifestRef = try await write(PDKManifestCodec.encode(manifest), "pdk.json", kind: "pdk.technology", format: .json)
        let definition = try PDKProfileDefinition(profileID: "fixture", manifestReference: manifestRef, processID: "p", version: "1",
            requiredCornerIDs: cornerIDs, requirements: requirements, sources: sources, orderedSearchRoutes: ["models"], dependencies: edges,
            inspectionPolicyIdentity: "policy.v1")
        let definitionRef = try await write(PDKProfileCodec().encodeDefinition(definition), "profile.json", kind: "pdk.profile", format: .json)
        let request = PDKProfileAdmissionRequest(definition: .init(reference: definitionRef, rootID: rootID,
            relativePath: try ArtifactRelativePath(segments: ["profile.json"]), budget: access),
            manifest: .init(reference: manifestRef, rootID: rootID, relativePath: try ArtifactRelativePath(segments: ["pdk.json"]), budget: access),
            roots: [try PDKProfileAuthorizedRoot(rootID: rootID, rootURL: root)], sources: bindings, budget: budget, inspectionPolicyIdentity: "policy.v1")
        return Self(root: root, request: request, definition: definition, manifest: manifest, rootReference: rootRef, childReference: child,
            expectedReadBytes: definitionRef.byteCount + manifestRef.byteCount + rootRef.byteCount + (child?.byteCount ?? 0) + extraRead)
    }
    func replacingBudget(_ budget: PDKAdmissionBudget) -> PDKProfileAdmissionRequest {
        .init(definition: request.definition, manifest: request.manifest, roots: request.roots,
            sources: request.sources, budget: budget, inspectionPolicyIdentity: request.inspectionPolicyIdentity)
    }
    func cleanup() {
        do { try FileManager.default.removeItem(at: root) } catch { Issue.record("Fixture cleanup failed: \(error)") }
    }
}

final class AdmissionCaptureProbe: PDKBoundedLocalSourceCapturing {
    private struct State { var resources: LocalPDKAdmissionResources?; var references: [ArtifactReference] = [] }
    private let state = Mutex(State())
    var resources: LocalPDKAdmissionResources? { state.withLock { $0.resources } }
    var references: [ArtifactReference] { state.withLock { $0.references } }
    func capture(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                 relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget, resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        state.withLock { $0.resources = resources as? LocalPDKAdmissionResources; $0.references.append(reference) }
        return try await LocalPDKBoundedSourceCapturer().capture(reference: reference, rootURL: rootURL,
            rootID: rootID, relativePath: relativePath, budget: budget, resources: resources)
    }
}

struct AdmissionScriptInspector: PDKProfileSourceInspecting {
    enum Behavior: Sendable, Equatable { case normal, empty, wrongIdentity, wrongMapping, wrongSection, omitCoverage, omitEvents, unsupported, suppressResolutionFailure, wrongPVT, nominalOnly }
    let edges: [PDKSourceDependency]
    var behavior: Behavior = .normal
    func inspect(_ request: PDKProfileSourceInspectionRequest, dependencies: any PDKProfileDependencyResolving,
                 resources: any PDKAdmissionResourceAccounting) async throws(PDKProfileInspectionError) -> PDKProfileSourceFacts {
        let work = PDKAdmissionWork(resources: resources)
        do throws(PDKProfileAdmissionError) {
            var inputs = PDKAdmissionCollection<PDKProfileSourceInput>()
            var events = PDKAdmissionCollection<PDKProfileDependencyEvent>()
            try inputs.append(request.input, work: work)
            func expand(_ parent: PDKProfileSourceInput) async throws(PDKProfileAdmissionError) {
                for edge in edges {
                    try work.step(); guard try work.equal(edge.parentSourceKey, parent.sourceKey) else { continue }
                    let child = try await dependencies.resolve(.init(parent: parent, statementByteOffset: edge.statementByteOffset,
                        statementOrdinal: edge.statementOrdinal, directiveKind: edge.directiveKind, literalRoute: edge.literalRoute,
                        selectedSection: edge.selectedSection, preprocessingIdentity: edge.preprocessingIdentity))
                    try inputs.append(child, work: work)
                    guard let event = child.incomingEvent else { throw .dependencyDrift }
                    try events.append(event, work: work); try await expand(child)
                }
            }
            if behavior == .suppressResolutionFailure {
                do { _ = try await dependencies.resolve(.init(parent: request.input, statementByteOffset: 0,
                    statementOrdinal: 999, directiveKind: "include", literalRoute: "undeclared.sp", selectedSection: nil,
                    preprocessingIdentity: "policy.v1")) } catch { /* Admission must retain this failure. */ }
            } else { try await expand(request.input) }
            let coverageLease = try work.capacity(PDKProfileSourceCoverage.self, inputs.count, dimension: .temporaryBytes)
            let eventLease = try work.capacity(PDKProfileDependencyEvent.self, events.count, dimension: .temporaryBytes)
            defer { withExtendedLifetime(coverageLease) {}; withExtendedLifetime(eventLease) {} }
            var coverage: [PDKProfileSourceCoverage] = []; coverage.reserveCapacity(inputs.count)
            var ordered: [PDKProfileDependencyEvent] = []; ordered.reserveCapacity(events.count)
            for event in events { try work.step(); ordered.append(event) }
            var activeOwners: [PDKAdmissionReservation] = []
            defer { withExtendedLifetime(activeOwners) {} }
            for input in inputs {
                let activeLease = try work.capacity(PDKProfileDependencyEvent.self, events.count, dimension: .temporaryBytes)
                if let activeLease { activeOwners.append(activeLease) }
                var active: [PDKProfileDependencyEvent] = []; active.reserveCapacity(events.count)
                for event in events { try work.step(); if event.parentNodeID == input.nodeID { active.append(event) } }
                coverage.append(.init(input: input, meaning: active.isEmpty ? .leaf : .complete,
                    observedSection: behavior == .wrongSection ? "foreign" : input.context.selectedSection, evidenceIdentity: "fixture.grammar",
                    activeDependencies: active, inactiveStatementOffsets: []))
            }
            let mappingLease = try work.capacity(PDKProfileMappingFact.self, behavior == .empty ? 0 : 1, dimension: .temporaryBytes)
            let mappings = behavior == .empty ? [] : [PDKProfileMappingFact(input: request.input, factKind: "devices", name: behavior == .wrongMapping ? "wrong" : "m")]
            defer { withExtendedLifetime(mappingLease) {} }
            var pvt: [PDKSourcePVTFact] = [], temperatures: [PDKSourceTemperatureFact] = []
            let pvtLease = try work.capacity(PDKSourcePVTFact.self, request.corner == nil ? 0 : 1, dimension: .temporaryBytes)
            let temperatureLease = try work.capacity(PDKSourceTemperatureFact.self, behavior == .nominalOnly ? 1 : 0, dimension: .temporaryBytes)
            defer { withExtendedLifetime(pvtLease) {}; withExtendedLifetime(temperatureLease) {} }
            if let corner = request.corner {
                if behavior == .nominalOnly {
                    do { temperatures = [try PDKSourceTemperatureFact(kind: "modelNominalTemperature", temperatureCelsius: 27,
                        sourceReference: request.input.reference, evidenceIdentity: "fixture.tnom", resources: resources)] }
                    catch { throw .selection(error) }
                } else {
                    var condition = corner.pvt
                    if behavior == .wrongPVT { condition.temperatureCelsius += 1 }
                    do { pvt = [try PDKSourcePVTFact(kind: "operating", pvt: condition, sourceReference: request.input.reference,
                        evidenceIdentity: "fixture.operating", resources: resources)] } catch { throw .selection(error) }
                }
            }
            do { return try PDKProfileSourceFacts(input: request.input, parserIdentity: behavior == .wrongIdentity ? "foreign" : "fixture.parser",
                policyIdentity: request.inspectionPolicyIdentity, mappings: mappings, pvt: pvt, temperatures: temperatures,
                coverage: behavior == .omitCoverage ? [] : coverage, events: behavior == .omitEvents ? [] : ordered,
                unsupportedFactKinds: behavior == .unsupported ? ["devices"] : [], lostFactKinds: [], resources: resources) }
            catch { if case .resource(let error) = error { throw .resource(error) }; throw .unsupportedSemantics }
        } catch { if case .resource(let error) = error { throw .resource(error) }; throw .unsupportedSemantics }
    }
    func registration() throws -> PDKProfileInspectorRegistration {
        try .init(format: .spice, parserIdentity: "fixture.parser", policyIdentity: "policy.v1", inspector: self)
    }
}
