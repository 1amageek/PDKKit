import PDKCore
import Synchronization

/// Decode-local live capacity is retained independently of the invocation's cumulative counters.
internal final class PDKDecodeResourceAccounting: PDKAdmissionResourceAccounting {
    private struct State {
        var owned: [PDKAdmissionReservation] = []
        var temporary: [PDKAdmissionReservation] = []
    }
    private let upstream: any PDKAdmissionResourceAccounting
    private let state = Mutex(State())

    init(_ upstream: any PDKAdmissionResourceAccounting) { self.upstream = upstream }

    func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
        let reservation = try upstream.reserve(cost)
        guard cost.dimension == .liveOwnedBytes || cost.dimension == .temporaryBytes else { return reservation }
        while true {
            let required = state.withLock { state in
                let handles = cost.dimension == .liveOwnedBytes ? state.owned : state.temporary
                let (minimum, overflow) = handles.count.addingReportingOverflow(2)
                return overflow ? Int.max : (minimum > handles.capacity ? minimum : 0)
            }
            let backing: PDKAdmissionReservation?
            let capacity: Int
            if required > 0 {
                let (next, overflow) = required.multipliedReportingOverflow(by: 2)
                guard !overflow else { throw .arithmeticOverflow(cost.dimension) }
                capacity = next
                let (bytes, byteOverflow) = UInt64(capacity).multipliedReportingOverflow(by: UInt64(MemoryLayout<PDKAdmissionReservation>.stride))
                guard !byteOverflow else { throw .arithmeticOverflow(cost.dimension) }
                backing = try upstream.reserve(PDKAdmissionCost(dimension: cost.dimension, amount: bytes))
            } else { backing = nil; capacity = 0 }
            let retained = state.withLock { state in
                if cost.dimension == .liveOwnedBytes {
                    return append(reservation, backing: backing, capacity: capacity, to: &state.owned)
                }
                return append(reservation, backing: backing, capacity: capacity, to: &state.temporary)
            }
            if retained { return reservation }
        }
    }

    private func append(_ reservation: PDKAdmissionReservation, backing: PDKAdmissionReservation?, capacity: Int,
                        to handles: inout [PDKAdmissionReservation]) -> Bool {
        let (minimum, overflow) = handles.count.addingReportingOverflow(2)
        guard !overflow else { return false }
        if minimum > handles.capacity {
            guard let backing, capacity >= minimum else { return false }
            handles.reserveCapacity(capacity)
            handles.append(backing)
        }
        handles.append(reservation)
        return true
    }

    func charge(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) {
        try upstream.charge(cost)
    }

    func check() throws(PDKAdmissionResourceError) { try upstream.check() }

    func takeOwned() -> [PDKAdmissionReservation] {
        state.withLock { state in
            let owned = state.owned
            state.owned = []
            return owned
        }
    }

    func charge(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64) throws {
        guard amount > 0 else { return }
        let cost = try PDKAdmissionCost(dimension: dimension, amount: amount)
        if dimension.isLiveCapacity { _ = try reserve(cost) }
        else { try charge(cost) }
    }

    func capacity(_ count: Int, stride: Int, dimension: PDKAdmissionResourceDimension = .temporaryBytes) throws {
        let (amount, overflow) = UInt64(count).multipliedReportingOverflow(by: UInt64(stride))
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(dimension) }
        try charge(dimension, amount)
    }
    func dictionaryCapacity(_ count: Int, keyStride: Int, valueStride: Int,
                            growing: Bool, dimension: PDKAdmissionResourceDimension) throws {
        guard count > 0 else { return }
        let (scaled, overflow) = count.multipliedReportingOverflow(by: 4)
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(dimension) }
        let required = scaled / 3 + 1
        var buckets = 1
        while buckets < required {
            let (next, overflow) = buckets.multipliedReportingOverflow(by: 2)
            guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(dimension) }
            buckets = next
        }
        let (stride, strideOverflow) = keyStride.addingReportingOverflow(valueStride)
        let copies = growing ? 2 : 1
        let (copiedStride, copyOverflow) = stride.multipliedReportingOverflow(by: copies)
        guard !strideOverflow, !copyOverflow else { throw PDKAdmissionResourceError.arithmeticOverflow(dimension) }
        try capacity(buckets, stride: copiedStride, dimension: dimension)
        let words = buckets / UInt.bitWidth + 1
        try capacity(words, stride: MemoryLayout<UInt>.stride * copies, dimension: dimension)
    }

    func grow<T>(_ values: inout [T]) throws {
        if values.count == values.capacity {
            let (nextCapacity, overflow) = max(values.capacity, 1).multipliedReportingOverflow(by: 2)
            guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.temporaryBytes) }
            try capacity(nextCapacity, stride: MemoryLayout<T>.stride)
            values.reserveCapacity(nextCapacity)
        }
    }

}
