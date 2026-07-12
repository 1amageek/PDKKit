import Foundation

public protocol PDKDiscoveryExecutionClock: Sendable {
    func now() -> Date
}
