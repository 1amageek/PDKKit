/// Monotonic invocation time, independent of artifact timestamps.
public protocol PDKAdmissionExecutionClock: Sendable {
    func now() -> ContinuousClock.Instant
}
