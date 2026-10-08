import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation

/// Creates one root; the caller must admit its descriptor before invoking this operation.
public protocol PDKSourceRootOpening: Sendable {
    func open(rootID: ArtifactRootID, directoryURL: URL, digester: any ContentDigesting)
        throws(ArtifactRootCapabilityError) -> any PDKSourceDiscoveryRoot
}
