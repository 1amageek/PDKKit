import CircuiteFoundation
import CircuiteFoundationFileSystem
import CoreSpiceIO
import Foundation
import PDKCore
import PDKDiscovery
import PDKProfileAdmission
import PDKSourceCapture
@testable import PDKSpiceProfileInspection
import Testing

struct SpiceProfileFixture {
    struct Edge {
        let parent: String
        let child: String
        let offset: UInt64
        let ordinal: UInt64
        var section: String? = nil
        var kind = "include"
        var parameters: [SPICEPreprocessingParameter] = []
    }
    let root: URL
    let request: PDKProfileAdmissionRequest
    let references: [String: ArtifactReference]
    let readBytes: UInt64
    static let policy = "spice.policy.v1"
    static func budget(overrides: [PDKAdmissionResourceDimension: UInt64] = [:]) throws -> PDKAdmissionBudget {
        var limits: [PDKAdmissionResourceDimension: UInt64] = [:]
        for dimension in PDKAdmissionResourceDimension.allCases { limits[dimension] = overrides[dimension] ?? 100_000_000 }
        return try .init(limits: limits, maximumElapsedNanoseconds: 20_000_000_000)
    }
    static func make(files: [String: String] = ["root": "* leaf\n.model m NMOS (level=1 vto=0.4)\n"],
                     edges: [Edge] = [], selectedSection: String? = nil,
                     demands: [String] = ["devices", "dependencyClosure"], logicalNames: [String] = ["m"],
                     initialIdentity: String? = nil) async throws -> Self {
        let root = FileManager.default.temporaryDirectory.appending(path: "pdk-spice-profile-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let rootID = try ArtifactRootID(rawValue: UUID().uuidString)
        let access = try ArtifactAccessBudget(maximumPageByteCount: 4096, maximumTotalByteCount: 10_000_000,
            maximumPageCount: 10_000, maximumWorkUnitCount: 100_000_000, maximumDurationNanoseconds: 20_000_000_000)
        let budget = try Self.budget()
        func write(_ data: Data, path: String, format: ArtifactFormat, kind: String) async throws -> ArtifactReference {
            try data.write(to: root.appending(path: path))
            let resources = LocalPDKAdmissionResources(budget: budget); defer { resources.close() }
            return try await LocalPDKBoundedSourceCapturer().discover(descriptor: .init(role: .input,
                kind: ArtifactKind(rawValue: kind), format: format), rootURL: root, rootID: rootID,
                relativePath: ArtifactRelativePath(segments: [path]), budget: access, resources: resources).reference
        }
        var references: [String: ArtifactReference] = [:]
        var sources: [PDKProfileSource] = [], bindings: [PDKProfileSourceBinding] = []
        for key in files.keys.sorted() {
            let reference = try await write(Data(files[key]!.utf8), path: key + ".sp", format: .spice, kind: "pdk.spice")
            references[key] = reference
            sources.append(try .init(sourceKey: key, assetID: key == "root" ? "model" : nil,
                reference: reference, logicalRoutes: [key + ".sp"]))
            bindings.append(try .init(sourceKey: key, logicalRoute: key + ".sp", rootID: rootID,
                relativePath: ArtifactRelativePath(segments: [key + ".sp"]), budget: access))
        }
        let resources = LocalPDKAdmissionResources(budget: budget); defer { resources.close() }
        let bridge = PDKSpiceResourceBridge(resources: resources)
        let configuration = ParserConfiguration(resolveIncludes: true)
        let empty = try SPICEPreprocessingEnvironment.empty(policyIdentity: policy, configuration: configuration,
            resources: bridge, maximumPageByteCount: 4096)
        var dependencies: [PDKSourceDependency] = []
        for (index, edge) in edges.enumerated() {
            let environment = try SPICEPreprocessingEnvironment.admit(parameters: edge.parameters,
                policyIdentity: policy, configuration: configuration, resources: bridge, maximumPageByteCount: 4096)
            dependencies.append(try .init(parentSourceKey: edge.parent, parentReference: references[edge.parent]!,
                statementByteOffset: edge.offset, statementOrdinal: edge.ordinal, directiveKind: edge.kind,
                literalRoute: edge.child + ".sp", childSourceKey: edge.child, childReference: references[edge.child]!,
                selectedSection: edge.section, preprocessingIdentity: environment.identity, lexicalOrder: UInt64(index + 1)))
        }
        let rootReference = references["root"]!
        let manifest = try PDKManifest(processID: "p", version: "1", assets: [
            .init(assetID: "model", role: .model, path: "root.sp", kind: ArtifactKind(rawValue: "spice"), format: .spice,
                required: true, sha256: rootReference.digest.hexadecimalValue, byteCount: Int64(rootReference.byteCount))],
            crossViewMappings: [.init(mappingID: "models", view: .spice, assetID: "model", logicalNames: logicalNames)])
        let manifestRef = try await write(PDKManifestCodec.encode(manifest), path: "pdk.json", format: .json, kind: "pdk.technology")
        let requirement = try PDKViewRequirement(requirementID: "simulation", purposeID: "transient", view: .spice,
            role: .model, assetIDs: ["model"], cornerIDs: [], selectedSection: selectedSection, isShared: true,
            allowsMultipleSources: false, demandedFactKinds: demands)
        let definition = try PDKProfileDefinition(profileID: "spice", manifestReference: manifestRef, processID: "p", version: "1",
            requiredCornerIDs: [], requirements: [requirement], sources: sources, orderedSearchRoutes: ["models"],
            dependencies: dependencies, inspectionPolicyIdentity: policy, initialPreprocessingIdentity: initialIdentity ?? empty.identity)
        let definitionRef = try await write(PDKProfileCodec().encodeDefinition(definition), path: "profile.json", format: .json, kind: "pdk.profile")
        let request = try PDKProfileAdmissionRequest(definition: .init(reference: definitionRef, rootID: rootID,
            relativePath: ArtifactRelativePath(segments: ["profile.json"]), budget: access),
            manifest: .init(reference: manifestRef, rootID: rootID, relativePath: ArtifactRelativePath(segments: ["pdk.json"]), budget: access),
            roots: [PDKProfileAuthorizedRoot(rootID: rootID, rootURL: root)], sources: bindings,
            budget: budget, inspectionPolicyIdentity: policy)
        return .init(root: root, request: request, references: references,
            readBytes: definitionRef.byteCount + manifestRef.byteCount + references.values.reduce(0) { $0 + $1.byteCount })
    }
    func replacingBudget(_ budget: PDKAdmissionBudget) -> PDKProfileAdmissionRequest {
        .init(definition: request.definition, manifest: request.manifest, roots: request.roots,
            sources: request.sources, budget: budget, inspectionPolicyIdentity: request.inspectionPolicyIdentity)
    }
    func admit(inspector: any PDKProfileSourceInspecting = LocalPDKSpiceProfileInspector(policyIdentity: Self.policy),
               resources: (any PDKAdmissionResourceAccounting)? = nil) async throws -> AdmittedPDKProfile {
        let registration = try PDKProfileInspectorRegistration(format: .spice,
            parserIdentity: LocalPDKSpiceProfileInspector.parserIdentity, policyIdentity: Self.policy, inspector: inspector)
        let admitter = LocalPDKProfileAdmitter(inspectors: [registration])
        if let resources { return try await admitter.admit(request, resources: resources) }
        return try await admitter.admit(request)
    }
    func remove() {
        do { try FileManager.default.removeItem(at: root) } catch { Issue.record("Fixture cleanup failed: \(error)") }
    }
}
