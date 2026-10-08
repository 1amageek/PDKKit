import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import PDKKitCLICore
import PDKProfileAdmission
import PDKSourceCapture
import Testing

struct CLIInputFixture {
    let root: PDKProfileAuthorizedRoot
    let access: ArtifactAccessBudget
    let budget: PDKAdmissionBudget
    let manifest: PDKProfileExactBinding
    let source: PDKProfileSourceBinding
    static func make() async throws -> Self {
        let url = FileManager.default.temporaryDirectory.appending(path: "pdk-cli-input-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let root = try PDKProfileAuthorizedRoot(rootID: ArtifactRootID(rawValue: UUID().uuidString), rootURL: url)
        let access = try ArtifactAccessBudget(maximumPageByteCount: 64, maximumTotalByteCount: 1_000_000,
            maximumPageCount: 20_000, maximumWorkUnitCount: 1_000_000, maximumDurationNanoseconds: 30_000_000_000)
        let budget = try PDKAdmissionBudget(limits: Dictionary(uniqueKeysWithValues:
            PDKAdmissionResourceDimension.allCases.map { ($0, UInt64(10_000_000)) }), maximumElapsedNanoseconds: 30_000_000_000)
        let resources = LocalPDKAdmissionResources(budget: budget); defer { resources.close() }
        try Data("{}".utf8).write(to: url.appending(path: "pdk.json"))
        let reference = try await LocalPDKBoundedSourceCapturer().discover(descriptor: .init(role: .input, kind: .technology, format: .json),
            rootURL: url, rootID: root.rootID, relativePath: ArtifactRelativePath(segments: ["pdk.json"]), budget: access, resources: resources).reference
        let source = PDKProfileSourceBinding(sourceKey: "model", logicalRoute: "model.sp", rootID: root.rootID,
            relativePath: try ArtifactRelativePath(segments: ["model.sp"]), budget: access)
        return .init(root: root, access: access, budget: budget, manifest: .init(reference: reference, rootID: root.rootID,
            relativePath: try ArtifactRelativePath(segments: ["pdk.json"]), budget: access), source: source)
    }
    func remove() {
        do { try FileManager.default.removeItem(at: root.rootURL) }
        catch { Issue.record("Temporary CLI input cleanup failed: \(error)") }
    }
    func availability(resources: any PDKAdmissionResourceAccounting) throws -> PDKProfileCLIAvailability {
        try .init(roots: [root], definition: nil, manifest: manifest, sources: [source], claim: nil,
                  inspectionPolicyIdentity: "policy.v1", resources: resources)
    }
    func authoring(resources: any PDKAdmissionResourceAccounting) throws -> PDKProfileCLIAuthoring {
        let candidate = try PDKProfileCLICandidateSource(sourceKey: source.sourceKey, assetID: "model",
            descriptor: .init(role: .input, kind: .model, format: .spice), logicalRoutes: [source.logicalRoute],
            bindings: [source], resources: resources)
        let requirement = try PDKViewRequirement(requirementID: "simulation", purposeID: "transient", view: .spice,
            role: .model, assetIDs: ["model"], cornerIDs: [], selectedSection: nil, isShared: true,
            allowsMultipleSources: false, demandedFactKinds: ["devices"], resources: resources)
        return try .init(profileID: "profile", requiredCornerIDs: [], requirements: [requirement], orderedSearchRoutes: [],
            inspectionPolicyIdentity: "policy.v1", candidateSources: [candidate], resources: resources)
    }
    func write(_ bytes: Data, name: String, descriptor: ArtifactDescriptor = PDKProfileCLIAvailability.artifactDescriptor) async throws -> PDKProfileExactBinding {
        try bytes.write(to: root.rootURL.appending(path: name))
        let resources = LocalPDKAdmissionResources(budget: budget); defer { resources.close() }
        let path = try ArtifactRelativePath(segments: [name])
        let capture = try await LocalPDKBoundedSourceCapturer().discover(descriptor: descriptor,
            rootURL: root.rootURL, rootID: root.rootID, relativePath: path, budget: access, resources: resources)
        return .init(reference: capture.reference, rootID: root.rootID, relativePath: path, budget: access)
    }
    func live(_ owner: LocalPDKAdmissionResources) throws -> UInt64 {
        let snapshot = try owner.snapshot()
        for item in snapshot.dimensions {
            if item.dimension == .liveOwnedBytes, case .live(let current, _) = item.usage { return current }
        }
        return 0
    }
}
