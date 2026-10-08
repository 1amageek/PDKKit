import CircuiteFoundationFileSystem
import PDKSourceCapture

actor BoundedCaptureTestRoot: PDKSourceDiscoveryRoot {
    private let root: ArtifactRootCapability
    private let owner: BoundedCaptureTestRootOpener
    init(root: ArtifactRootCapability, owner: BoundedCaptureTestRootOpener) { self.root = root; self.owner = owner }
    func discover(_ intent: ArtifactSourceDiscoveryIntent, control: any ArtifactSourceControl)
        async throws(ArtifactSourceDiscoveryError) -> ArtifactDiscoveredSource {
        let selected = ArtifactSourceDiscoveryIntent(rootID: intent.rootID, relativePath: intent.relativePath,
            descriptor: owner.replacementDescriptor ?? intent.descriptor, budget: intent.budget)
        return try await root.discover(selected, control: control)
    }
    func enumerate(_ intent: ArtifactDirectoryInventoryIntent, control: any ArtifactSourceControl)
        async throws(ArtifactSourceDiscoveryError) -> ArtifactDirectoryInventory {
        try await root.enumerate(intent, control: control)
    }
    func shutdown() async throws(ArtifactRootCapabilityError) {
        try await root.close().wait()
        owner.didShutDown()
        if let failure = owner.lateFailure { owner.accounting.failure = failure }
        if owner.closeFailure { throw .closeFailed(reason: "injected root close") }
    }
}
