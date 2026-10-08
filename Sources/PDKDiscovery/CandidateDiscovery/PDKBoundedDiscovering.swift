import CircuiteFoundation
import PDKCore

public protocol PDKBoundedDiscovering: Sendable {
    func discover(roots: [PDKBoundedDiscoveryRoot], descriptor: ArtifactDescriptor,
                  processID: String?, resources: any PDKAdmissionResourceAccounting)
        async throws(PDKBoundedDiscoveryError) -> PDKBoundedDiscoveryResult
}
