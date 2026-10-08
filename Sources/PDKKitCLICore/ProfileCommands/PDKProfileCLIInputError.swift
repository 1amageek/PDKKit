import CircuiteFoundationFileSystem
import PDKCore
import PDKDiscovery
import PDKSourceCapture

public indirect enum PDKProfileCLIInputError: Error, Sendable, Equatable {
    case invalidBinding
    case invalidBootstrapPolicy
    case unsupportedSinglePageAcquisition
    case bootstrap(PDKBudgetBootstrapError)
    case source(PDKSourceCaptureError)
    case root(ArtifactRootCapabilityError)
    case discovery(ArtifactSourceDiscoveryError)
    case decode(PDKBoundedDecodeError)
    case resource(PDKAdmissionResourceError)
    case cleanup(primary: PDKProfileCLIInputError, cleanup: ArtifactRootCapabilityError)
}
