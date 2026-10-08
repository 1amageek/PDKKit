import CoreSpiceIO
import PDKCore

/// Uses the existing invocation owner for lower grammar work and storage.
struct PDKSpiceResourceBridge: SPICESourceResourceAccounting {
    let resources: any PDKAdmissionResourceAccounting

    func checkCancellation() throws {
        try resources.check()
        guard !Task.isCancelled else { throw PDKAdmissionResourceError.cancelled }
    }
    func charge(_ kind: SPICESourceWorkKind, units: UInt64) throws {
        try checkCancellation()
        // Capture owns actual filesystem reads; lower admission only observes the same bytes.
        guard kind != .sourceBytes, units > 0 else { return }
        _ = try resources.reserve(PDKAdmissionCost(dimension: .parserWork, amount: units))
    }
    func chargeHashedBytes(_ byteCount: UInt64) throws {
        try checkCancellation()
        guard byteCount > 0 else { return }
        _ = try resources.reserve(PDKAdmissionCost(dimension: .hashedBytes, amount: byteCount))
    }
    func reserveStorage(kind: SPICESourceStorageKind, byteCount: UInt64) throws -> SPICESourceStorageReservation {
        try checkCancellation()
        guard byteCount > 0 else { return .init(kind: kind, byteCount: 0, release: {}) }
        let dimension: PDKAdmissionResourceDimension = kind == .liveOwnedBytes ? .liveOwnedBytes : .temporaryBytes
        let reservation = try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: byteCount))
        return .init(kind: kind, byteCount: byteCount, release: { withExtendedLifetime(reservation) {} })
    }
    func equal(_ lhs: String, _ rhs: String) throws -> Bool {
        var left = lhs.utf8.makeIterator(), right = rhs.utf8.makeIterator()
        while true {
            try charge(.lexicalBytes, units: 2)
            let a = left.next(), b = right.next()
            if a != b { return false }
            if a == nil { return true }
        }
    }
    func array<Element: Sendable>(_ values: SPICEAccountedCollection<Element>) throws -> (values: [Element], owner: SPICESourceStorageReservation) {
        let owner = try SPICESourceCapacity.reserve(of: Element.self, capacity: values.count,
            kind: .temporaryBytes, resources: self)
        var output: [Element] = []; output.reserveCapacity(values.count)
        for value in values { try charge(.retainedElements, units: 1); output.append(value) }
        return (output, owner)
    }
}
