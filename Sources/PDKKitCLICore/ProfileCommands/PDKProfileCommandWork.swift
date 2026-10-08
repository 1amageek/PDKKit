import CircuiteFoundation
import PDKCore

/// Invocation-local admission for command conversion and container boundaries.
struct PDKProfileCommandWork {
    let resources: any PDKAdmissionResourceAccounting
    func step(_ amount: UInt64 = 1) throws {
        try resources.check()
        if amount > 0 { _ = try resources.reserve(.init(dimension: .parserWork, amount: amount)) }
    }
    func bytes(_ value: String) throws -> UInt64 {
        var count: UInt64 = 0
        for _ in value.utf8 {
            try step()
            let (next, overflow) = count.addingReportingOverflow(1)
            guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.parserWork) }
            count = next
        }
        return count
    }
    func equal(_ a: String, _ b: String) throws -> Bool {
        let first = try bytes(a), second = try bytes(b)
        let (total, overflow) = first.addingReportingOverflow(second)
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.parserWork) }
        try step(total); return a == b
    }
    func reserve<T>(_ type: T.Type, count: Int, dimension: PDKAdmissionResourceDimension = .liveOwnedBytes)
        throws -> PDKAdmissionReservation {
        guard count >= 0 else { throw PDKAdmissionResourceError.arithmeticOverflow(dimension) }
        let (amount, overflow) = UInt64(count).multipliedReportingOverflow(by: UInt64(MemoryLayout<T>.stride))
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(dimension) }
        return try resources.reserve(.init(dimension: dimension, amount: amount))
    }
}
