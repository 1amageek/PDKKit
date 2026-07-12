import Foundation

public protocol PDKValidationExecutionClock: Sendable {
    func now() -> Date
}
