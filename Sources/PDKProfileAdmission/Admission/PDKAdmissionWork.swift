import CircuiteFoundation
import PDKCore

struct PDKAdmissionWork: Sendable {
    let resources: any PDKAdmissionResourceAccounting
    func check() throws(PDKProfileAdmissionError) {
        do { try resources.check() } catch { throw .resource(error) }
        guard !Task.isCancelled else { throw .resource(.cancelled) }
    }
    func reserve(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64)
        throws(PDKProfileAdmissionError) -> PDKAdmissionReservation {
        try check()
        do { return try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: amount)) }
        catch { throw .resource(error) }
    }
    func charge(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64 = 1) throws(PDKProfileAdmissionError) {
        try check()
        guard amount > 0 else { return }
        do { try resources.charge(PDKAdmissionCost(dimension: dimension, amount: amount)) }
        catch { throw .resource(error) }
    }
    func step() throws(PDKProfileAdmissionError) { try charge(.parserWork) }
    func capacity<T>(_ type: T.Type, _ count: Int, dimension: PDKAdmissionResourceDimension = .liveOwnedBytes)
        throws(PDKProfileAdmissionError) -> PDKAdmissionReservation? {
        try check()
        guard count >= 0 else { throw .resource(.arithmeticOverflow(dimension)) }
        let (amount, overflow) = UInt64(count).multipliedReportingOverflow(by: UInt64(MemoryLayout<T>.stride))
        guard !overflow else { throw .resource(.arithmeticOverflow(dimension)) }
        return amount == 0 ? nil : try reserve(dimension, amount)
    }
    func bytes(_ value: String) throws(PDKProfileAdmissionError) -> UInt64 {
        var iterator = value.utf8.makeIterator(), count: UInt64 = 0
        while true {
            try step(); guard iterator.next() != nil else { return count }
            let (next, overflow) = count.addingReportingOverflow(1)
            guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }; count = next
        }
    }
    func equal(_ a: String, _ b: String) throws(PDKProfileAdmissionError) -> Bool {
        let left = try bytes(a), right = try bytes(b)
        let (amount, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
        try charge(.parserWork, amount); let same = a == b; try check(); return same
    }
    func equal(_ a: String?, _ b: String?) throws(PDKProfileAdmissionError) -> Bool {
        try step()
        switch (a, b) { case (.some(let a), .some(let b)): return try equal(a, b)
        case (.none, .none): return true; default: return false }
    }
    func equal(_ a: ArtifactReference, _ b: ArtifactReference) throws(PDKProfileAdmissionError) -> Bool {
        try step()
        guard a.byteCount == b.byteCount, a.digest.algorithm == b.digest.algorithm else { return false }
        guard try equal(a.digest.hexadecimalValue, b.digest.hexadecimalValue) else { return false }
        guard try equal(a.descriptor.role.rawValue, b.descriptor.role.rawValue) else { return false }
        guard try equal(a.descriptor.kind.rawValue, b.descriptor.kind.rawValue) else { return false }
        return try equal(a.descriptor.format.rawValue, b.descriptor.format.rawValue)
    }
    func equal(_ a: PDKProfileSourceContext, _ b: PDKProfileSourceContext) throws(PDKProfileAdmissionError) -> Bool {
        guard try equal(a.cornerID, b.cornerID) else { return false }
        guard try equal(a.sourceKey, b.sourceKey) else { return false }
        guard try equal(a.selectedSection, b.selectedSection) else { return false }
        return try equal(a.preprocessingIdentity, b.preprocessingIdentity)
    }
    func equal(_ a: PDKSourceDependency, _ b: PDKSourceDependency) throws(PDKProfileAdmissionError) -> Bool {
        try step()
        guard a.statementByteOffset == b.statementByteOffset, a.statementOrdinal == b.statementOrdinal,
              a.lexicalOrder == b.lexicalOrder else { return false }
        guard try equal(a.parentSourceKey, b.parentSourceKey), try equal(a.parentReference, b.parentReference),
              try equal(a.directiveKind, b.directiveKind), try equal(a.literalRoute, b.literalRoute),
              try equal(a.childSourceKey, b.childSourceKey), try equal(a.childReference, b.childReference),
              try equal(a.selectedSection, b.selectedSection) else { return false }
        return try equal(a.preprocessingIdentity, b.preprocessingIdentity)
    }
}
