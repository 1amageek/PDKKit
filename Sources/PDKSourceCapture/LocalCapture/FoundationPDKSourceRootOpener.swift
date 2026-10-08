import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation

public struct FoundationPDKSourceRootOpener: PDKSourceRootOpening {
    public init() {}
    public func open(rootID: ArtifactRootID, directoryURL: URL, digester: any ContentDigesting)
        throws(ArtifactRootCapabilityError) -> any PDKSourceDiscoveryRoot {
        try ArtifactRootCapability(rootID: rootID, directoryURL: directoryURL, digester: digester)
    }
}
