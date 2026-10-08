import CircuiteFoundationFileSystem

/// Controlled discovery and the teardown of its explicit authorizing root.
public protocol PDKSourceDiscoveryRoot: Sendable {
    func discover(_ intent: ArtifactSourceDiscoveryIntent, control: any ArtifactSourceControl)
        async throws(ArtifactSourceDiscoveryError) -> ArtifactDiscoveredSource
    func enumerate(_ intent: ArtifactDirectoryInventoryIntent, control: any ArtifactSourceControl)
        async throws(ArtifactSourceDiscoveryError) -> ArtifactDirectoryInventory
    func shutdown() async throws(ArtifactRootCapabilityError)
}

extension ArtifactRootCapability: PDKSourceDiscoveryRoot {
    public func shutdown() async throws(ArtifactRootCapabilityError) { try await close().wait() }
}
