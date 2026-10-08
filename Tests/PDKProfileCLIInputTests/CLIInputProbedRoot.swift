import CircuiteFoundationFileSystem
import PDKSourceCapture

struct CLIInputProbedRoot: PDKSourceDiscoveryRoot {
    let base: any PDKSourceDiscoveryRoot
    let probe: CLIInputRootProbe
    func discover(_ intent: ArtifactSourceDiscoveryIntent, control: any ArtifactSourceControl)
        async throws(ArtifactSourceDiscoveryError) -> ArtifactDiscoveredSource {
        if let gate = probe.gate { await gate.pause() }
        do { try control.check() } catch { throw .control(error) }
        if probe.failDiscovery { throw .control(.cancelled) }
        return try await base.discover(intent, control: CLIInputProbedControl(base: control, probe: probe))
    }
    func enumerate(_ intent: ArtifactDirectoryInventoryIntent, control: any ArtifactSourceControl)
        async throws(ArtifactSourceDiscoveryError) -> ArtifactDirectoryInventory {
        try await base.enumerate(intent, control: control)
    }
    func shutdown() async throws(ArtifactRootCapabilityError) {
        try await base.shutdown()
        probe.state.withLock { $0.shuts += 1 }
        if probe.failShutdown { throw .closeFailed(reason: "injected root shutdown failure") }
    }
}
