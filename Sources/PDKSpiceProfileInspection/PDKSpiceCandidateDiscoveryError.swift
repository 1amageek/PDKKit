import PDKCore
import PDKProfileAdmission
import PDKSourceCapture

public enum PDKSpiceCandidateDiscoveryError: Error, Sendable, Equatable {
    case resource(PDKAdmissionResourceError)
    case source(PDKSourceCaptureError)
    case syntax(PDKProfileSyntaxDiagnostic)
    case value(PDKProfileValueError)
    case missingRoute, ambiguousRoute, escapingRoute, contextualCycle, invalidRequest, unsupportedSemantics
}
