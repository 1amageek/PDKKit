import PDKCore
import PDKSourceCapture

public enum PDKBoundedDiscoveryFailure: Error, Sendable, Equatable {
    case invalidRootURL
    case duplicateRootID
    case duplicateRootURL
    case invalidFormat
    case resource(PDKAdmissionResourceError)
    case enumeration(PDKSourceCaptureError)
    case manifest(PDKBoundedManifestLoadingError)
}
