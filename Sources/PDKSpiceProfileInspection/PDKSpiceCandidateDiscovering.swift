import PDKCore

/// Observes a draft graph through grammar-owned traversal; grants no admission.
public protocol PDKSpiceCandidateDiscovering: Sendable {
    func initialPreprocessingIdentity(resources: any PDKAdmissionResourceAccounting)
        throws(PDKSpiceCandidateDiscoveryError) -> PDKSpiceInitialPreprocessingIdentity
    func discover(_ request: PDKSpiceCandidateDiscoveryRequest,
                  resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSpiceCandidateDiscoveryError) -> PDKSpiceCandidateGraph
}
