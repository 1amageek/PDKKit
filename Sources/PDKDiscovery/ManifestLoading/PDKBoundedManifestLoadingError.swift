import CircuiteFoundation
import PDKCore
import PDKSourceCapture

public enum PDKBoundedManifestLoadingError: Error, Sendable, Equatable {
    case invalidFormat
    case descriptorMismatch(expected: ArtifactDescriptor, actual: ArtifactDescriptor)
    case source(PDKSourceCaptureError)
    case decode(PDKBoundedDecodeError)
    case resource(PDKAdmissionResourceError)
    case substitutedSource(expected: ArtifactReference, actual: ArtifactReference)
    case decodedSourceMismatch(expected: ArtifactReference, actual: ArtifactReference?)

    public var isCancellation: Bool {
        switch self {
        case .resource(.cancelled), .decode(.resource(.cancelled)): true
        case .source(let error): Self.cancelled(error.classification)
        default: false
        }
    }
    private static func cancelled(_ classification: PDKSourceCaptureFailureClassification) -> Bool {
        switch classification {
        case .cancellation: true
        case .cleanup(let primary, let failure):
            (primary.map(cancelled) ?? false) || cancelled(failure)
        default: false
        }
    }
}
