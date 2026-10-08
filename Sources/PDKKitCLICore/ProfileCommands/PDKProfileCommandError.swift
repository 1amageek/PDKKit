import PDKCore
import PDKDiscovery
import PDKSourceCapture
import PDKProfileAdmission
import PDKSpiceProfileInspection

public enum PDKProfileCommandError: Error, Sendable {
    case invalidArguments
    case input(PDKProfileCLIInputError)
    case source(PDKSourceCaptureError)
    case decode(PDKBoundedDecodeError)
    case manifest(PDKBoundedManifestLoadingError)
    case selection(PDKProfileValueError)
    case admission(PDKProfileAdmissionError)
    case candidate(PDKSpiceCandidateDiscoveryError)
    case output(PDKProfileOutputError)
    case resource(PDKAdmissionResourceError)
    case replayMismatch
    case unsupportedFormat
    case unexpected(any Error)

    var code: String {
        switch self {
        case .invalidArguments: "invalid-arguments"
        case .input: "input-failure"
        case .source: "source-failure"
        case .decode: "decode-failure"
        case .manifest: "manifest-failure"
        case .selection: "selection-failure"
        case .admission: "admission-failure"
        case .candidate: "candidate-failure"
        case .output: "output-failure"
        case .resource(.cancelled): "cancelled"
        case .resource(.deadlineExceeded): "deadline-exceeded"
        case .resource: "resource-failure"
        case .replayMismatch: "replay-mismatch"
        case .unsupportedFormat: "unsupported-format"
        case .unexpected: "unexpected-failure"
        }
    }
    var exitCode: Int32 {
        switch self { case .invalidArguments, .input, .output: 1; default: 2 }
    }
    var terminalStatus: String {
        switch self {
        case .resource(.cancelled), .selection(.resource(.cancelled)), .decode(.resource(.cancelled)),
             .input(.resource(.cancelled)), .candidate(.resource(.cancelled)), .output(.resource(.cancelled)): "cancelled"
        case .admission(let error): error.isCancellation ? "cancelled" : admissionStatus(error)
        case .manifest(let error): error.isCancellation ? "cancelled" : "failed"
        case .source(let error): Self.cancelled(error.classification) ? "cancelled" : "failed"
        case .unsupportedFormat, .candidate(.unsupportedSemantics), .resource(.unsupportedBudgetCapability): "blocked"
        default: "failed"
        }
    }
    private func admissionStatus(_ error: PDKProfileAdmissionError) -> String {
        switch error.underlyingReason {
        case .unsupportedSemantics, .inspection(.unsupportedSemantics), .inspection(.unsupportedFormat),
             .resource(.unsupportedBudgetCapability): "blocked"
        default: "failed"
        }
    }
    private static func cancelled(_ classification: PDKSourceCaptureFailureClassification) -> Bool {
        switch classification {
        case .cancellation: true
        case .cleanup(let primary, let failure): (primary.map(cancelled) ?? false) || cancelled(failure)
        default: false
        }
    }
    static func preserving(_ error: any Error) -> Self {
        if let value = error as? Self { return value }
        if let value = error as? PDKProfileCLIInputError { return .input(value) }
        if let value = error as? PDKSourceCaptureError { return .source(value) }
        if let value = error as? PDKBoundedDecodeError { return .decode(value) }
        if let value = error as? PDKBoundedManifestLoadingError { return .manifest(value) }
        if let value = error as? PDKProfileValueError { return .selection(value) }
        if let value = error as? PDKProfileAdmissionError { return .admission(value) }
        if let value = error as? PDKSpiceCandidateDiscoveryError { return .candidate(value) }
        if let value = error as? PDKProfileOutputError { return .output(value) }
        if let value = error as? PDKAdmissionResourceError { return .resource(value) }
        return .unexpected(error)
    }
}
