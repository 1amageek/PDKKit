import CircuiteFoundation
import CircuiteFoundationFileSystem
import Synchronization

/// A separate fixed bootstrap acquisition, never a replacement profile accountant.
final class PDKBudgetAcquisitionControl: ArtifactSourceControl {
    private struct State {
        var read: UInt64 = 0, hashed: UInt64 = 0, pages: UInt64 = 0, work: UInt64 = 0
        var owned: UInt64 = 0, temporary: UInt64 = 0, opened: UInt64 = 0
        var peakOwned: UInt64 = 0, peakTemporary: UInt64 = 0, peakOpened: UInt64 = 0
    }
    private let state = Mutex(State())
    private let budget: ArtifactAccessBudget
    private let ownedLimit: UInt64
    private let workLimit: UInt64
    private let openLimit: UInt64
    private let started = ContinuousClock.now
    private let duration: Duration
    init(budget: ArtifactAccessBudget, path: ArtifactRelativePath) throws(PDKProfileCLIInputError) {
        self.budget = budget
        let page = min(budget.maximumPageByteCount, 1_048_576)
        let pages = (budget.maximumTotalByteCount - 1) / page + 1
        let stride = UInt64(MemoryLayout<[UInt8]>.stride + MemoryLayout<any ArtifactSourceRetention>.stride)
        let (slots, a) = pages.multipliedReportingOverflow(by: stride)
        let (payload, b) = slots.addingReportingOverflow(budget.maximumTotalByteCount)
        let (owned, c) = payload.addingReportingOverflow(UInt64(MemoryLayout<any ArtifactSourceRetention>.stride))
        let (work, d) = budget.maximumWorkUnitCount.addingReportingOverflow(budget.maximumTotalByteCount)
        guard !a, !b, !c, !d else { throw .invalidBootstrapPolicy }
        ownedLimit = owned; workLimit = work; openLimit = UInt64(path.segments.count) + 3
        duration = .seconds(Int64(budget.maximumDurationNanoseconds / 1_000_000_000))
            + .nanoseconds(Int64(budget.maximumDurationNanoseconds % 1_000_000_000))
    }
    func check() throws(ArtifactSourceControlError) {
        guard !Task.isCancelled else { throw .cancelled }
        guard ContinuousClock.now - started < duration else { throw .deadlineExceeded }
    }
    private func sum(_ prior: UInt64, _ amount: UInt64, limit: UInt64,
                     resource: ArtifactSourceResource) throws(ArtifactSourceControlError) -> UInt64 {
        let (next, overflow) = prior.addingReportingOverflow(amount)
        guard !overflow else { throw .arithmeticOverflow(resource: resource) }
        guard next <= limit else { throw .quotaExceeded(resource: resource, limit: limit, attempted: next) }
        return next
    }
    func charge(_ work: ArtifactSourceWork) throws(ArtifactSourceControlError) {
        try check()
        guard work.visitedEntries == 0 else { throw .unsupportedCapability(reason: "Bootstrap does not enumerate") }
        try state.withLock { (state) throws(ArtifactSourceControlError) in
            let read = try sum(state.read, work.readBytes, limit: budget.maximumTotalByteCount, resource: .readBytes)
            let hashed = try sum(state.hashed, work.hashedBytes, limit: budget.maximumTotalByteCount, resource: .hashedBytes)
            let pages = try sum(state.pages, work.pages, limit: budget.maximumPageCount, resource: .pages)
            let units = try sum(state.work, work.workUnits, limit: workLimit, resource: .workUnits)
            state.read = read; state.hashed = hashed; state.pages = pages; state.work = units
        }
    }
    func retain(_ extent: ArtifactSourceExtent) throws(ArtifactSourceControlError) -> any ArtifactSourceRetention {
        try check()
        try state.withLock { (state) throws(ArtifactSourceControlError) in
            switch extent {
            case .ownedBytes(let amount):
                state.owned = try sum(state.owned, amount, limit: ownedLimit, resource: .ownedBytes)
                state.peakOwned = max(state.peakOwned, state.owned)
            case .temporaryBytes(let amount):
                state.temporary = try sum(state.temporary, amount, limit: budget.maximumTotalByteCount, resource: .temporaryBytes)
                state.peakTemporary = max(state.peakTemporary, state.temporary)
            case .openResources(let amount):
                state.opened = try sum(state.opened, amount, limit: openLimit, resource: .openResources)
                state.peakOpened = max(state.peakOpened, state.opened)
            }
        }
        return PDKBudgetAcquisitionRetention { [self] in
            state.withLock { state in
                switch extent {
                case .ownedBytes(let amount): state.owned -= amount
                case .temporaryBytes(let amount): state.temporary -= amount
                case .openResources(let amount): state.opened -= amount
                }
            }
        }
    }
    func snapshot() -> PDKBudgetAcquisitionObservations {
        state.withLock {
            .init(readByteCount: $0.read, hashedByteCount: $0.hashed, pageCount: $0.pages, workUnitCount: $0.work,
                ownedByteCount: $0.owned, peakOwnedByteCount: $0.peakOwned,
                temporaryByteCount: $0.temporary, peakTemporaryByteCount: $0.peakTemporary,
                openResourceCount: $0.opened, peakOpenResourceCount: $0.peakOpened)
        }
    }
}
