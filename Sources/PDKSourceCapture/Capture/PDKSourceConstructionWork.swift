import CircuiteFoundation
import PDKCore

/// Synchronous local work only; the accountant owns shared invocation state.
struct PDKSourceConstructionWork {
    let resources: any PDKAdmissionResourceAccounting
    func check() throws(PDKSourceCaptureError) {
        do { try resources.check() } catch { throw .resource(error) }
        if Task.isCancelled { throw .resource(.cancelled) }
    }
    func checkDeadline(_ started: ContinuousClock.Instant, maximumNanoseconds: UInt64) throws(PDKSourceCaptureError) {
        try check()
        let elapsed = (ContinuousClock.now - started).components
        let seconds = UInt64(max(elapsed.seconds, 0)).multipliedReportingOverflow(by: 1_000_000_000)
        let fraction = UInt64(max(elapsed.attoseconds, 0)) / 1_000_000_000
        let total = seconds.partialValue.addingReportingOverflow(fraction)
        guard !seconds.overflow, !total.overflow, total.partialValue < maximumNanoseconds else {
            throw .resource(.deadlineExceeded)
        }
    }
    func reserve(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64)
        throws(PDKSourceCaptureError) -> PDKAdmissionReservation? {
        try check()
        guard amount > 0 else { return nil }
        do { return try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: amount)) }
        catch { throw .resource(error) }
    }
    func charge(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64) throws(PDKSourceCaptureError) {
        _ = try reserve(dimension, amount)
    }
    private func stringWork(_ value: String) throws(PDKSourceCaptureError) -> UInt64 {
        var count: UInt64 = 0
        for _ in value.utf8 {
            try charge(.parserWork, 1)
            let (next, overflow) = count.addingReportingOverflow(1)
            guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
            count = next
        }
        return count
    }
    func equal(_ lhs: String, _ rhs: String) throws(PDKSourceCaptureError) -> Bool {
        let left = try stringWork(lhs), right = try stringWork(rhs)
        let (total, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
        try charge(.parserWork, total)
        return lhs == rhs
    }
    func equal(_ lhs: ArtifactReference, _ rhs: ArtifactReference) throws(PDKSourceCaptureError) -> Bool {
        try check()
        guard lhs.byteCount == rhs.byteCount, lhs.digest.algorithm == rhs.digest.algorithm else { return false }
        guard try equal(lhs.digest.hexadecimalValue, rhs.digest.hexadecimalValue) else { return false }
        guard try equal(lhs.descriptor.role.rawValue, rhs.descriptor.role.rawValue) else { return false }
        guard try equal(lhs.descriptor.kind.rawValue, rhs.descriptor.kind.rawValue) else { return false }
        return try equal(lhs.descriptor.format.rawValue, rhs.descriptor.format.rawValue)
    }
}
