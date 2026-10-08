import PDKCore

struct PDKCandidateDiscoveryWork {
    let resources: any PDKAdmissionResourceAccounting
    func check() throws(PDKBoundedDiscoveryFailure) {
        do { try resources.check() } catch { throw .resource(error) }
        guard !Task.isCancelled else { throw .resource(.cancelled) }
    }
    func charge(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64) throws(PDKBoundedDiscoveryFailure) {
        try check()
        guard amount > 0 else { return }
        do { _ = try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: amount)) }
        catch { throw .resource(error) }
    }
    func step() throws(PDKBoundedDiscoveryFailure) { try charge(.parserWork, 1) }
    func capacity(_ count: Int) throws(PDKBoundedDiscoveryFailure) -> PDKAdmissionReservation {
        try check()
        let (amount, overflow) = UInt64(count).multipliedReportingOverflow(by: UInt64(MemoryLayout<PDKBoundedCandidate?>.stride))
        guard !overflow else { throw .resource(.arithmeticOverflow(.liveOwnedBytes)) }
        do { return try resources.reserve(PDKAdmissionCost(dimension: .liveOwnedBytes, amount: amount)) }
        catch { throw .resource(error) }
    }
    func bytes(_ value: String) throws(PDKBoundedDiscoveryFailure) -> UInt64 {
        var iterator = value.utf8.makeIterator()
        var count: UInt64 = 0
        while true {
            try step()
            guard iterator.next() != nil else { return count }
            let (next, overflow) = count.addingReportingOverflow(1)
            guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
            count = next
        }
    }
    func equal(_ lhs: String, _ rhs: String) throws(PDKBoundedDiscoveryFailure) -> Bool {
        let left = try bytes(lhs), right = try bytes(rhs)
        let (count, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
        try charge(.parserWork, count)
        let result = lhs == rhs
        try check()
        return result
    }
}
