import PDKCore
@testable import PDKProfileAdmission
import Testing

@Suite(.timeLimit(.minutes(1)))
struct AdmissionCollectionTests {
    @Test(arguments: [false, true])
    func copiedCollectionWritesReserveTheirWholeBackingBeforeMutation(replacing: Bool) throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        defer { resources.close() }
        let work = PDKAdmissionWork(resources: resources)
        var original = PDKAdmissionCollection<Int>()
        for value in 0..<3 { try original.append(value, work: work) }
        let bytes = UInt64(4 * MemoryLayout<Int?>.stride)
        #expect(original.managedCapacity == 4)
        #expect(resources.used(.liveOwnedBytes) == bytes)
        var changed = original
        if replacing { try changed.replace(at: 1, with: 9, work: work) }
        else { try changed.append(9, work: work) }
        #expect(original.count == 3 && original[1] == 1)
        #expect(changed.managedCapacity == 4)
        #expect(replacing ? changed[1] == 9 : changed[3] == 9)
        #expect(resources.used(.liveOwnedBytes) == 2 * bytes)
        var lastCopy = changed
        changed.removeAll()
        #expect(lastCopy.count == (replacing ? 3 : 4))
        #expect(resources.used(.liveOwnedBytes) == 2 * bytes)
        original.removeAll()
        #expect(resources.used(.liveOwnedBytes) == bytes)
        lastCopy.removeAll()
        #expect(resources.used(.liveOwnedBytes) == 0)
    }
    @Test(arguments: [false, true])
    func refusedCopiedWritePreservesBothSnapshotsAndTheOriginalLease(replacing: Bool) throws {
        let bytes = UInt64(4 * MemoryLayout<Int?>.stride)
        let resources = LocalPDKAdmissionResources(budget: try budget(liveLimit: 2 * bytes - 1))
        defer { resources.close() }
        let work = PDKAdmissionWork(resources: resources)
        var original = PDKAdmissionCollection<Int>()
        for value in 0..<3 { try original.append(value, work: work) }
        var changed = original
        do {
            if replacing { try changed.replace(at: 1, with: 9, work: work) }
            else { try changed.append(9, work: work) }
            Issue.record("A copied write silently allocated unreserved capacity")
        } catch let error as PDKProfileAdmissionError {
            guard case .resource(.exhausted(.liveOwnedBytes, _, _)) = error else { Issue.record("Wrong capacity refusal"); return }
        }
        #expect(original.count == 3 && original[1] == 1)
        #expect(changed.count == 3 && changed[1] == 1)
        #expect(resources.used(.liveOwnedBytes) == bytes)
        original.removeAll(); #expect(resources.used(.liveOwnedBytes) == bytes)
        changed.removeAll(); #expect(resources.used(.liveOwnedBytes) == 0)
    }
    private func budget(liveLimit: UInt64 = 100_000) throws -> PDKAdmissionBudget {
        var limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64(100_000)) })
        limits[.liveOwnedBytes] = liveLimit
        return try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: 10_000_000_000)
    }
}
