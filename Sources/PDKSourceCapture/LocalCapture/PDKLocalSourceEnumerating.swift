import CircuiteFoundationFileSystem
import Foundation
import PDKCore

/// Enumerates generic local entries; candidate selection belongs to Discovery.
public protocol PDKLocalSourceEnumerating: Sendable {
    func enumerate(intent: ArtifactDirectoryInventoryIntent, rootURL: URL,
                   resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> ArtifactDirectoryInventory
}
