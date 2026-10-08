public enum PDKSourceCaptureFailureClassification: Sendable, Equatable {
    case cancellation
    case digestMismatch
    case byteCountMismatch
    case other
    indirect case cleanup(
        primary: PDKSourceCaptureFailureClassification?,
        failure: PDKSourceCaptureFailureClassification
    )
}
