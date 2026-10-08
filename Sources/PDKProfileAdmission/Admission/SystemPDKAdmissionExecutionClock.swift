public struct SystemPDKAdmissionExecutionClock: PDKAdmissionExecutionClock {
    public init() {}
    public func now() -> ContinuousClock.Instant { ContinuousClock.now }
}
