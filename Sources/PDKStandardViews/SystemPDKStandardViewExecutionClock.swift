import Foundation

public struct SystemPDKStandardViewExecutionClock: PDKStandardViewExecutionClock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}
