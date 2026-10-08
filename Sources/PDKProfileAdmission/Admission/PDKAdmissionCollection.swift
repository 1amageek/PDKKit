import PDKCore

/// Immutable outside the checked admission algorithm; copies retain slot capacity.
public struct PDKAdmissionCollection<Element: Sendable>: RandomAccessCollection, Sendable {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    private var slots: [Element?] = []
    private var capacityOwner: PDKAdmissionReservation?
    private var identity = PDKAdmissionCollectionIdentity()
    public private(set) var endIndex = 0
    public var startIndex: Int { 0 }
    public var managedCapacity: Int { slots.count }
    public var indices: Range<Int> { 0..<endIndex }
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < endIndex)
        guard let value = slots[index] else { preconditionFailure("Uninitialized admitted slot") }; return value
    }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    internal init() {}
    internal mutating func append(_ value: Element, work: PDKAdmissionWork) throws(PDKProfileAdmissionError) {
        try work.step()
        if endIndex == slots.count {
            let (doubled, overflow) = slots.count.multipliedReportingOverflow(by: 2)
            guard !overflow else { throw .resource(.arithmeticOverflow(.liveOwnedBytes)) }
            let capacity = Swift.max(1, doubled)
            try migrate(to: capacity, work: work)
        } else if !isKnownUniquelyReferenced(&identity) {
            try migrate(to: slots.count, work: work)
        }
        slots[endIndex] = value; endIndex += 1; try work.check()
    }
    internal mutating func replace(at index: Int, with value: Element,
                                   work: PDKAdmissionWork) throws(PDKProfileAdmissionError) {
        precondition(index >= 0 && index < endIndex)
        try work.step()
        if !isKnownUniquelyReferenced(&identity) { try migrate(to: slots.count, work: work) }
        slots[index] = value; try work.check()
    }
    private mutating func migrate(to capacity: Int, work: PDKAdmissionWork) throws(PDKProfileAdmissionError) {
        let lease = try work.capacity(Optional<Element>.self, capacity)
        var next: [Element?] = []; next.reserveCapacity(capacity)
        for index in 0..<capacity { try work.step(); next.append(index < endIndex ? slots[index] : nil) }
        slots = next; capacityOwner = lease; identity = PDKAdmissionCollectionIdentity()
    }
    // Completion replaces an already admitted slot even when accounting is terminal.
    // Registry/resolver collections never escape or expose their backing, and their
    // range indices retain no collection copy. Completion therefore allocates nothing.
    internal mutating func complete(at index: Int, with value: Element) {
        precondition(isKnownUniquelyReferenced(&identity), "Terminal completion requires invocation-owned storage")
        slots[index] = value
    }
    internal mutating func removeAll() {
        slots = []; capacityOwner = nil; endIndex = 0; identity = PDKAdmissionCollectionIdentity()
    }
}
