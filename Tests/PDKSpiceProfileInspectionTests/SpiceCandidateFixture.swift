import CircuiteFoundation
import Foundation
import PDKCore
import PDKProfileAdmission
import PDKSpiceProfileInspection
import Testing

struct SpiceCandidateFixture {
    let root: URL
    let request: PDKSpiceCandidateDiscoveryRequest
    let totalByteCount: UInt64
    static func make(files: [String: String], entries: [PDKSpiceCandidateEntry]? = nil,
                     searches: [String] = []) throws -> Self {
        let root = FileManager.default.temporaryDirectory.appending(path: "pdk-spice-candidate-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let rootID = try ArtifactRootID(rawValue: UUID().uuidString)
        let access = try ArtifactAccessBudget(maximumPageByteCount: 4096, maximumTotalByteCount: 10_000_000,
            maximumPageCount: 10_000, maximumWorkUnitCount: 100_000_000, maximumDurationNanoseconds: 20_000_000_000)
        var bindings: [PDKSpiceCandidateBinding] = []
        var total: UInt64 = 0
        for key in files.keys.sorted() {
            let data = Data(files[key]!.utf8)
            try data.write(to: root.appending(path: key + ".sp"))
            total += UInt64(data.count)
            bindings.append(try .init(sourceKey: key, assetID: key == "root" ? "model" : nil,
                logicalRoutes: [key + ".sp"], rootID: rootID,
                relativePath: ArtifactRelativePath(segments: [key + ".sp"]), budget: access,
                descriptor: .init(role: .input, kind: ArtifactKind(rawValue: "pdk.spice"), format: .spice)))
        }
        return try .init(root: root, request: .init(roots: [PDKProfileAuthorizedRoot(rootID: rootID, rootURL: root)],
            sources: bindings, entries: entries ?? [.init(sourceKey: "root", logicalRoute: "root.sp")],
            orderedSearchRoutes: searches), totalByteCount: total)
    }
    func changing(sources: [PDKSpiceCandidateBinding], entries: [PDKSpiceCandidateEntry]? = nil,
                  searches: [String]? = nil) -> PDKSpiceCandidateDiscoveryRequest {
        .init(roots: request.roots, sources: sources, entries: entries ?? request.entries,
            orderedSearchRoutes: searches ?? request.orderedSearchRoutes)
    }
    func discover(_ request: PDKSpiceCandidateDiscoveryRequest? = nil,
                  resources: (any PDKAdmissionResourceAccounting)? = nil) async throws -> PDKSpiceCandidateGraph {
        if let resources {
            return try await LocalPDKSpiceCandidateDiscoverer(policyIdentity: SpiceProfileFixture.policy)
                .discover(request ?? self.request, resources: resources)
        }
        let resources = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget())
        defer { resources.close() }
        return try await LocalPDKSpiceCandidateDiscoverer(policyIdentity: SpiceProfileFixture.policy)
            .discover(request ?? self.request, resources: resources)
    }
    func remove() {
        do { try FileManager.default.removeItem(at: root) } catch { Issue.record("Fixture cleanup failed: \(error)") }
    }
}
