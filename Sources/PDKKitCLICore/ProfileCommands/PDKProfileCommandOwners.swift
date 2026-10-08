import PDKCore
import PDKDiscovery
import PDKSourceCapture
import PDKProfileAdmission
import PDKSpiceProfileInspection

/// Fixed invocation slots retain lower immutable owners through final result copies.
struct PDKProfileCommandOwners: Sendable {
    var bootstrap: PDKLoadedBudgetBootstrap?
    var availability: PDKDecodedDocument<PDKProfileCLIAvailability>?
    var availabilityBinding: PDKProfileExactBinding?
    var authoring: PDKDecodedDocument<PDKProfileCLIAuthoring>?
    var authoringBinding: PDKProfileExactBinding?
    var manifest: PDKBoundedLoadedManifest?
    var definitionCapture: CapturedPDKSource?
    var definitionDocument: PDKDecodedDocument<PDKProfileDefinition>?
    var claimCapture: CapturedPDKSource?
    var claimDocument: PDKDecodedDocument<PDKProfileClaim>?
    var admitted: AdmittedPDKProfile?
    var graph: PDKSpiceCandidateGraph?
    var initialIdentity: PDKSpiceInitialPreprocessingIdentity?
    var plan: PDKProfilePlan?
    var catalog: PDKProfileCatalogSelection?
    var definition: PDKProfileDefinition?
    var captures: [CapturedPDKSource] = []
    var sources: [PDKProfileSource] = []
    var spiceBindings: [PDKSpiceCandidateBinding] = []
    var entries: [PDKSpiceCandidateEntry] = []
    var reservations: [PDKAdmissionReservation] = []
}
