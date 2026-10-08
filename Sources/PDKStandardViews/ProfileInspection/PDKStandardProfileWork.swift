import CircuiteFoundation
import PDKCore
import PDKProfileAdmission

internal struct PDKStandardProfileWork {
    let resources: any PDKAdmissionResourceAccounting

    func check() throws(PDKProfileInspectionError) {
        do { try resources.check() } catch { throw .resource(error) }
        guard !Task.isCancelled else { throw .resource(.cancelled) }
    }
    func charge(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64 = 1) throws(PDKProfileInspectionError) {
        try check()
        do { _ = try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: amount)) }
        catch { throw .resource(error) }
    }
    func capacity<Value>(_ type: Value.Type, count: Int) throws(PDKProfileInspectionError) -> PDKAdmissionReservation? {
        try check()
        guard count >= 0 else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        let (bytes, overflow) = UInt64(count).multipliedReportingOverflow(by: UInt64(MemoryLayout<Value>.stride))
        guard !overflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        guard bytes > 0 else { return nil }
        do { return try resources.reserve(PDKAdmissionCost(dimension: .temporaryBytes, amount: bytes)) }
        catch { throw .resource(error) }
    }
    func equal(_ left: String, _ right: String) throws(PDKProfileInspectionError) -> Bool {
        let a = try bytes(left), b = try bytes(right)
        let (count, overflow) = a.addingReportingOverflow(b)
        guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
        if count > 0 { try charge(.parserWork, count) }
        let same = left == right
        try check(); return same
    }
    private func bytes(_ value: String) throws(PDKProfileInspectionError) -> UInt64 {
        var iterator = value.utf8.makeIterator(), count: UInt64 = 0
        while true {
            try charge(.parserWork)
            guard iterator.next() != nil else { return count }
            let (next, overflow) = count.addingReportingOverflow(1)
            guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
            count = next
        }
    }
    func equal(_ left: ArtifactReference, _ right: ArtifactReference) throws(PDKProfileInspectionError) -> Bool {
        try charge(.parserWork)
        guard left.byteCount == right.byteCount, left.digest.algorithm == right.digest.algorithm else { return false }
        guard try equal(left.digest.hexadecimalValue, right.digest.hexadecimalValue),
              try equal(left.descriptor.role.rawValue, right.descriptor.role.rawValue),
              try equal(left.descriptor.kind.rawValue, right.descriptor.kind.rawValue) else { return false }
        return try equal(left.descriptor.format.rawValue, right.descriptor.format.rawValue)
    }
}
