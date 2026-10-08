import CircuiteFoundation
import CircuiteFoundationFileSystem
import PDKCore
import PDKSourceCapture

public struct LocalPDKBoundedDiscoverer: PDKBoundedDiscovering {
    private let enumerator: any PDKLocalSourceEnumerating
    private let loader: any PDKBoundedManifestLoading
    public init(enumerator: any PDKLocalSourceEnumerating = LocalPDKBoundedSourceCapturer(),
                loader: any PDKBoundedManifestLoading = LocalPDKBoundedManifestLoader()) {
        self.enumerator = enumerator; self.loader = loader
    }
    public func discover(roots: [PDKBoundedDiscoveryRoot], descriptor: ArtifactDescriptor,
                         processID: String?, resources: any PDKAdmissionResourceAccounting)
        async throws(PDKBoundedDiscoveryError) -> PDKBoundedDiscoveryResult {
        let work = PDKCandidateDiscoveryWork(resources: resources)
        var completedRoots = 0, observedCandidates = 0
        var candidates = PDKBoundedCandidateCollection()
        do throws(PDKBoundedDiscoveryFailure) {
            try work.check()
            guard try work.equal(descriptor.format.rawValue, ArtifactFormat.json.rawValue) else { throw .invalidFormat }
            for index in roots.indices {
                try work.step()
                for prior in roots[..<index] {
                    try work.step()
                    if try work.equal(prior.inventory.rootID.rawValue, roots[index].inventory.rootID.rawValue) { throw .duplicateRootID }
                    if try work.equal(prior.binding, roots[index].binding) { throw .duplicateRootURL }
                }
            }
            for root in roots {
                try work.charge(.searchRoots, 1)
                let inventory: CircuiteFoundationFileSystem.ArtifactDirectoryInventory
                do { inventory = try await enumerator.enumerate(intent: root.inventory, rootURL: root.rootURL, resources: resources) }
                catch { throw .enumeration(error) }
                try work.check()
                for entry in inventory.entries {
                    try work.step()
                    guard entry.kind == .regularFile, let name = entry.relativePath.segments.last else { continue }
                    guard try work.equal(name, PDKManifest.fileName) else { continue }
                    try work.charge(.candidates, 1)
                    let (next, overflow) = observedCandidates.addingReportingOverflow(1)
                    guard !overflow else { throw .resource(.arithmeticOverflow(.candidates)) }
                    observedCandidates = next
                    let loaded: PDKBoundedLoadedManifest
                    do {
                        loaded = try await loader.discover(descriptor: descriptor, rootURL: root.rootURL,
                            rootID: root.inventory.rootID, relativePath: entry.relativePath,
                            budget: root.sourceBudget, resources: resources)
                    } catch { throw .manifest(error) }
                    try work.check()
                    if let processID {
                        guard try work.equal(loaded.manifest.processID, processID) else { continue }
                    }
                    try candidates.append(root: root, entry: entry, loaded: loaded, work: work)
                }
                completedRoots += 1
            }
            try work.check()
            return PDKBoundedDiscoveryResult(candidates: candidates,
                progress: .init(completedRootCount: completedRoots, observedCandidateCount: observedCandidates))
        } catch {
            throw .incomplete(progress: .init(completedRootCount: completedRoots, observedCandidateCount: observedCandidates), failure: error)
        }
    }
}
