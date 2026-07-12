import Foundation

public struct SystemPDKDiscoveryExecutionClock: PDKDiscoveryExecutionClock {
    public init() {}

    public func now() -> Date { Date() }
}
