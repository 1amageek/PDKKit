/// Copyable owner handle. The trusted accountant's release action runs exactly once
/// when the last copy releases this owner, never when an individual copy disappears.
public struct PDKAdmissionReservation: Sendable {
    public let cost: PDKAdmissionCost
    private let owner: Owner
    public init(cost: PDKAdmissionCost, onRelease: @escaping @Sendable () -> Void) {
        self.cost = cost
        self.owner = Owner(onRelease: onRelease)
    }
    private final class Owner: Sendable {
        let onRelease: @Sendable () -> Void
        init(onRelease: @escaping @Sendable () -> Void) { self.onRelease = onRelease }
        deinit { onRelease() }
    }
}
