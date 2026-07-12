import Foundation

public struct SystemPDKValidationExecutionClock: PDKValidationExecutionClock {
    public init() {}

    public func now() -> Date { Date() }
}
