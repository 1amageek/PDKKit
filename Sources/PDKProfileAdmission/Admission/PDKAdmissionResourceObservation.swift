import PDKCore

/// One configured dimension's accepted usage at the snapshot boundary.
public struct PDKAdmissionResourceObservation: Sendable, Equatable {
    public enum Usage: Sendable, Equatable {
        case cumulative(total: UInt64)
        case live(current: UInt64, peak: UInt64)
    }

    public let dimension: PDKAdmissionResourceDimension
    public let limit: UInt64
    public let usage: Usage

    internal init(dimension: PDKAdmissionResourceDimension, limit: UInt64, usage: Usage) {
        self.dimension = dimension
        self.limit = limit
        self.usage = usage
    }
}
