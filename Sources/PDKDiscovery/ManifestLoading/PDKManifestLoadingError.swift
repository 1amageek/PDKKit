import PDKCore
import PDKSourceCapture

public enum PDKManifestLoadingError: Error, Sendable, Equatable {
    case invalidInput(reason: String)
    case discovery(reason: String)
    case source(PDKSourceCaptureError)
    case manifest(PDKManifestError)
    case reference(PDKReferenceError)
    case cancelled

    public var isCancellation: Bool {
        switch self {
        case .cancelled: true
        case .source(let error): Self.containsCancellation(error.classification)
        default: false
        }
    }
    private static func containsCancellation(_ classification: PDKSourceCaptureFailureClassification) -> Bool {
        switch classification {
        case .cancellation: true
        case .cleanup(let primary, let failure):
            primary.map(containsCancellation) == true || containsCancellation(failure)
        default: false
        }
    }
}
