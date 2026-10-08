import PDKCore

public enum PDKProfileInspectionError: Error, Sendable, Equatable {
    case resource(PDKAdmissionResourceError)
    case unsupportedFormat
    case malformedSource
    case unsupportedSemantics
    case invalidFacts
}
