import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation
import PDKSourceCapture
import Synchronization

final class CLIInputRootProbe: PDKSourceRootOpening {
    struct State { var opens = 0; var shuts = 0; var readBytes: UInt64 = 0 }
    let state = Mutex(State())
    let failDiscovery: Bool
    let failShutdown: Bool
    let gate: CLIInputGate?
    init(failDiscovery: Bool = false, failShutdown: Bool = false, gate: CLIInputGate? = nil) {
        self.failDiscovery = failDiscovery; self.failShutdown = failShutdown; self.gate = gate
    }
    func open(rootID: ArtifactRootID, directoryURL: URL, digester: any ContentDigesting)
        throws(ArtifactRootCapabilityError) -> any PDKSourceDiscoveryRoot {
        state.withLock { $0.opens += 1 }
        let base = try FoundationPDKSourceRootOpener().open(rootID: rootID, directoryURL: directoryURL, digester: digester)
        return CLIInputProbedRoot(base: base, probe: self)
    }
}
