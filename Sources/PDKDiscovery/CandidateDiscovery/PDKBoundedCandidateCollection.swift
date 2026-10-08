import CircuiteFoundationFileSystem
import PDKCore

/// Immutable published slots; copied candidates retain this snapshot's capacity.
public struct PDKBoundedCandidateCollection: RandomAccessCollection, Sendable {
    public typealias Index = Int
    public typealias Element = PDKBoundedCandidate
    private var slots: [PDKBoundedCandidate?] = []
    public private(set) var endIndex: Int = 0
    public var startIndex: Int { 0 }
    public var managedCapacity: Int { slots.count }
    public subscript(index: Int) -> PDKBoundedCandidate {
        precondition(index >= 0 && index < endIndex)
        guard let value = slots[index] else { preconditionFailure("Published candidate slot is uninitialized") }
        return value
    }
    public func index(after index: Int) -> Int { index + 1 }
    public func index(before index: Int) -> Int { index - 1 }
    internal init() {}

    internal mutating func append(root: PDKBoundedDiscoveryRoot,
        entry: CircuiteFoundationFileSystem.ArtifactDirectoryEntry, loaded: PDKBoundedLoadedManifest,
        work: PDKCandidateDiscoveryWork) throws(PDKBoundedDiscoveryFailure) {
        try work.step()
        if endIndex == slots.count {
            let (doubled, overflow) = slots.count.multipliedReportingOverflow(by: 2)
            guard !overflow else { throw .resource(.arithmeticOverflow(.liveOwnedBytes)) }
            let capacity = Swift.max(1, doubled)
            let lease = try work.capacity(capacity)
            // Explicit initialization preserves cooperative checks across a large growth.
            var next: [PDKBoundedCandidate?] = []
            next.reserveCapacity(capacity)
            for _ in 0..<capacity { try work.step(); next.append(nil) }
            for index in 0..<endIndex {
                try work.step()
                next[index] = self[index].retaining(lease)
            }
            try work.step()
            next[endIndex] = PDKBoundedCandidate(root: root, entry: entry, loaded: loaded, capacity: lease)
            slots = next
        } else {
            // At least one initialized candidate carries the current buffer's lease.
            let lease = self[0].collectionLease
            slots[endIndex] = PDKBoundedCandidate(root: root, entry: entry, loaded: loaded, capacity: lease)
        }
        endIndex += 1
        try work.check()
    }
}
