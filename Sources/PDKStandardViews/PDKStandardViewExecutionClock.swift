import Foundation

public protocol PDKStandardViewExecutionClock: Sendable {
    func now() -> Date
}
