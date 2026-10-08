import CircuiteFoundationFileSystem
import PDKCore
import PDKDiscovery
import PDKSourceCapture

public enum PDKProfileAdmissionError: Error, Sendable, Equatable {
    case retained(PDKRetainedAdmissionFailure)
    case resource(PDKAdmissionResourceError)
    case source(PDKSourceCaptureError)
    case definition(PDKBoundedDecodeError)
    case manifest(PDKBoundedManifestLoadingError)
    case selection(PDKProfileValueError)
    case inspection(PDKProfileInspectionError)
    case missingBinding, ambiguousAvailability, policyMismatch
    case missingDependency, ambiguousDependency, dependencyDrift, contextualCycle
    case providerIdentity, missingCoverage, unsupportedSemantics, mappingMismatch, pvtMismatch
    /// A raw payload copy transfers backing-lifetime accounting to the caller.
    public var underlyingReason: PDKProfileAdmissionError {
        if case .retained(let owner) = self { return owner.underlyingReason.underlyingReason }; return self
    }
    internal var requiresDefinitionOwner: Bool {
        switch self {
        case .source(let error): Self.sourcePayload(error)
        case .manifest(.source(let error)): Self.sourcePayload(error)
        case .manifest(.descriptorMismatch), .manifest(.substitutedSource), .manifest(.decodedSourceMismatch): true
        default: false
        }
    }
    private static func sourcePayload(_ error: PDKSourceCaptureError) -> Bool {
        switch error {
        case .digestMismatch, .access(.contentDigestMismatch), .access(.contentIdentityMismatch): true
        case .cleanup(let primary, let cleanup): sourcePayload(primary) || sourcePayload(cleanup)
        case .discovery(let error): discoveryPayload(error)
        default: false
        }
    }
    private static func discoveryPayload(_ error: ArtifactSourceDiscoveryError) -> Bool {
        switch error {
        case .access(.contentDigestMismatch), .access(.contentIdentityMismatch): true
        case .cleanupFailed(let primary, _): primary.map(discoveryPayload) ?? false
        case .digestAbortFailed(let primary, _): discoveryPayload(primary)
        default: false
        }
    }
    public var isCancellation: Bool {
        switch self {
        case .resource(.cancelled), .definition(.resource(.cancelled)), .selection(.resource(.cancelled)), .inspection(.resource(.cancelled)): true
        case .retained(let owner): owner.underlyingReason.isCancellation
        case .manifest(let error): error.isCancellation
        case .source(let error): Self.cancelled(error.classification)
        default: false
        }
    }
    private static func cancelled(_ classification: PDKSourceCaptureFailureClassification) -> Bool {
        switch classification {
        case .cancellation: true
        case .cleanup(let primary, let failure): (primary.map(cancelled) ?? false) || cancelled(failure)
        default: false
        }
    }
}
