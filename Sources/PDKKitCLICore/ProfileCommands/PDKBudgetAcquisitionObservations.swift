public struct PDKBudgetAcquisitionObservations: Sendable, Equatable, Encodable {
    public let readByteCount: UInt64
    public let hashedByteCount: UInt64
    public let pageCount: UInt64
    public let workUnitCount: UInt64
    public let ownedByteCount: UInt64
    public let peakOwnedByteCount: UInt64
    public let temporaryByteCount: UInt64
    public let peakTemporaryByteCount: UInt64
    public let openResourceCount: UInt64
    public let peakOpenResourceCount: UInt64
}
