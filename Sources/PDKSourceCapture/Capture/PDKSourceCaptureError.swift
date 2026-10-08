import CircuiteFoundation
import CircuiteFoundationFileSystem
import PDKCore

public enum PDKSourceCaptureError: Error, Sendable, Equatable {
    case resource(PDKAdmissionResourceError)
    case discovery(ArtifactSourceDiscoveryError)
    case access(ArtifactAccessError)
    case digest(ContentDigestError)
    case root(ArtifactRootCapabilityError)
    case invalidLocation(reason: String)
    case invalidPage(reason: String)
    case byteLimitExceeded(limit: UInt64, actual: UInt64)
    case pageLimitExceeded(limit: UInt64)
    case workLimitExceeded(limit: UInt64)
    case deadlineExceeded
    case byteCountMismatch(expected: UInt64, actual: UInt64)
    case digestMismatch(expected: ContentDigest, actual: ContentDigest)
    case receiptMismatch
    case cancelled
    case sessionCleanup(ArtifactAccessTerminationError)
    case invalidTermination
    indirect case cleanup(primary: PDKSourceCaptureError, cleanup: PDKSourceCaptureError)

    public var classification: PDKSourceCaptureFailureClassification {
        switch self {
        case .cancelled, .access(.cancelled), .resource(.cancelled): .cancellation
        case .digestMismatch, .access(.contentDigestMismatch): .digestMismatch
        case .byteCountMismatch, .access(.byteCountMismatch): .byteCountMismatch
        case .cleanup(let primary, let cleanup):
            .cleanup(primary: primary.classification, failure: cleanup.classification)
        case .sessionCleanup, .invalidTermination, .root(.closeFailed), .access(.cleanupFailed), .access(.fileCloseFailed):
            .cleanup(primary: nil, failure: .other)
        default: .other
        }
    }
}
