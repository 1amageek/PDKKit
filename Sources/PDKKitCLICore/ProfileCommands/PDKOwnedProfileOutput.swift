import PDKCore

/// Immutable owned JSON bytes; copies share their original capacity reservation.
public struct PDKOwnedProfileOutput: Sendable {
    private let owner: Owner
    public var byteCount: Int { owner.bytes.count }
    internal var resources: any PDKAdmissionResourceAccounting { owner.resources }

    internal init(bytes: consuming [UInt8], resources: any PDKAdmissionResourceAccounting,
                  reservations: [PDKAdmissionReservation]) {
        self.owner = Owner(bytes: bytes, resources: resources, reservations: reservations)
    }

    public func withBytes<Result>(_ body: (borrowing Span<UInt8>) throws -> Result) rethrows -> Result {
        let retainedOwner = owner
        let bytes = retainedOwner.bytes
        defer { withExtendedLifetime(retainedOwner) {} }
        return try body(bytes.span)
    }

    private final class Owner: Sendable {
        let bytes: [UInt8]
        let resources: any PDKAdmissionResourceAccounting
        let reservations: [PDKAdmissionReservation]
        init(bytes: consuming [UInt8], resources: any PDKAdmissionResourceAccounting,
             reservations: [PDKAdmissionReservation]) {
            self.bytes = bytes; self.resources = resources; self.reservations = reservations
        }
    }
}
