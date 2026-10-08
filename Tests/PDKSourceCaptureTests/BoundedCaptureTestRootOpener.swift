import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation
import PDKCore
import PDKSourceCapture
import Synchronization

final class BoundedCaptureTestRootOpener: PDKSourceRootOpening {
    private let opens = Mutex(0)
    private let shuts = Mutex(0)
    let closeFailure: Bool
    let lateFailure: PDKAdmissionResourceError?
    let accounting: BoundedCaptureTestAccounting
    let replacementDescriptor: ArtifactDescriptor?
    var openCount: Int { opens.withLock { $0 } }
    var shutdownCount: Int { shuts.withLock { $0 } }
    init(accounting: BoundedCaptureTestAccounting, closeFailure: Bool = false,
         lateFailure: PDKAdmissionResourceError? = nil, replacementDescriptor: ArtifactDescriptor? = nil) {
        self.accounting = accounting; self.closeFailure = closeFailure
        self.lateFailure = lateFailure; self.replacementDescriptor = replacementDescriptor
    }
    func open(rootID: ArtifactRootID, directoryURL: URL, digester: any ContentDigesting)
        throws(ArtifactRootCapabilityError) -> any PDKSourceDiscoveryRoot {
        opens.withLock { $0 += 1 }
        let root = try ArtifactRootCapability(rootID: rootID, directoryURL: directoryURL, digester: digester)
        return BoundedCaptureTestRoot(root: root, owner: self)
    }
    func didShutDown() { shuts.withLock { $0 += 1 } }
}
