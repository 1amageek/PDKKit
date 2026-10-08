import PDKCore

public enum PDKProfileOutputError: Error, Sendable {
    case resource(PDKAdmissionResourceError)
    case codec(any Error)
    case sink(PDKProfileOutputSinkError)
    case shortWrite(expected: Int, actual: Int)
    case invalidEncoding
    case nonFiniteNumber
    case capacityOverflow
    case invalidCompletionPolicy
    case completionAlreadyUsed
    case suffixCapacityExceeded
    case elapsedOverflow

    internal static func preserving(_ error: any Error) -> Self {
        if let error = error as? Self { return error }
        if let error = error as? PDKAdmissionResourceError { return .resource(error) }
        return .codec(error)
    }
}
