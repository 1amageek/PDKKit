import PDKCore
import PDKDiscovery
import PDKSourceCapture

/// An immutable checked owner, never reconstructed from a serialized claim.
public struct AdmittedPDKProfile: Sendable {
    public let claim: PDKProfileClaim
    public let sourceInputs: PDKAdmissionCollection<PDKProfileSourceInput>
    public let sourceFacts: PDKAdmissionCollection<PDKProfileSourceFacts>
    public let definitionSource: CapturedPDKSource
    public let manifest: PDKBoundedLoadedManifest
    internal let dependencies: PDKAdmissionCollection<PDKProfileDependencyEvent>
    internal let rootOccurrences: PDKAdmissionCollection<PDKProfileRootOccurrence>
    internal let authority: PDKProfileInputAuthority
    internal init(claim: PDKProfileClaim, inputs: PDKAdmissionCollection<PDKProfileSourceInput>,
                  facts: PDKAdmissionCollection<PDKProfileSourceFacts>, dependencies: PDKAdmissionCollection<PDKProfileDependencyEvent>,
                  roots: PDKAdmissionCollection<PDKProfileRootOccurrence>, authority: PDKProfileInputAuthority,
                  manifest: PDKBoundedLoadedManifest, work: PDKAdmissionWork) throws(PDKProfileAdmissionError) {
        try work.check()
        self.claim = claim; sourceInputs = inputs; sourceFacts = facts; self.dependencies = dependencies
        rootOccurrences = roots; self.authority = authority; definitionSource = authority.definitionSource; self.manifest = manifest
    }
}
