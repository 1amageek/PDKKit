import CircuiteFoundation
import CircuiteFoundationCrypto

/// Encoding v1 uses framed UTF-8 and finite binary64 with normalized zero.
public struct PDKProfileCanonicalEncoding: Sendable {
    public static let version: UInt64 = 1
    public init() {}

    func buffer(definitionReference: ArtifactReference, definition: PDKProfileDefinition,
                corners: [PDKProfileCorner], selections: [PDKProfileSelection],
                sources: [PDKProfileSource], dependencies: [PDKSourceDependency],
                mandatorySupportSourceKeys: [String],
                resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) -> Buffer {
        let work = PDKProfileConstructionWork(resources)
        var sizing = Writer(sizing: true, work: work)
        try encode(into: &sizing, definitionReference: definitionReference, definition: definition,
            corners: corners, selections: selections, sources: sources, dependencies: dependencies,
            mandatorySupportSourceKeys: mandatorySupportSourceKeys, work: work)
        guard let capacity = Int(exactly: sizing.byteCount) else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        try work.temporary(UInt8.self, capacity: capacity)
        var writer = Writer(sizing: false, work: work)
        writer.bytes.reserveCapacity(capacity)
        try encode(into: &writer, definitionReference: definitionReference, definition: definition,
            corners: corners, selections: selections, sources: sources, dependencies: dependencies,
            mandatorySupportSourceKeys: mandatorySupportSourceKeys, work: work)
        guard writer.byteCount == sizing.byteCount else { throw .noncanonicalEncoding("Canonical framing size changed") }
        try work.check()
        return Buffer(bytes: writer.bytes, reservations: work.retainTemporaries())
    }

    private func encode(into w: inout Writer, definitionReference: ArtifactReference, definition: PDKProfileDefinition,
                        corners: [PDKProfileCorner], selections: [PDKProfileSelection], sources: [PDKProfileSource],
                        dependencies: [PDKSourceDependency], mandatorySupportSourceKeys: [String],
                        work: PDKProfileConstructionWork) throws(PDKProfileValueError) {
        try w.string("PDKKit.Profile.Selection")
        try w.uint(Self.version)
        try w.reference(definitionReference)
        try w.reference(definition.manifestReference)
        try w.string(definition.profileID); try w.string(definition.processID); try w.string(definition.version)
        try w.strings(try work.sorted(definition.requiredCornerIDs, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) }))
        try w.array(try work.sorted(definition.requirements, by: { (lhs, rhs) throws(PDKProfileValueError) in try work.less(lhs.requirementID, rhs.requirementID) })) { (w: inout Writer, r: PDKViewRequirement) throws(PDKProfileValueError) in
            try w.string(r.requirementID); try w.string(r.purposeID); try w.string(r.view.rawValue); try w.string(r.role.rawValue)
            try w.strings(r.allowsMultipleSources ? r.assetIDs : try work.sorted(r.assetIDs, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) })); try w.strings(try work.sorted(r.cornerIDs, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) })); try w.optional(r.selectedSection)
            try w.bool(r.isShared); try w.bool(r.allowsMultipleSources); try w.strings(try work.sorted(r.demandedFactKinds, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) }))
        }
        try w.array(try work.sorted(corners, by: { (lhs, rhs) throws(PDKProfileValueError) in try work.less(lhs.cornerID, rhs.cornerID) })) { (w: inout Writer, c: PDKProfileCorner) throws(PDKProfileValueError) in
            try w.string(c.cornerID); try w.string(c.pvt.process.name); try w.bool(c.pvt.process.nominal)
            try w.number(c.pvt.voltage); try w.number(c.pvt.temperatureCelsius)
        }
        try w.array(try work.sorted(selections, by: work.selectionLess)) { (w: inout Writer, s: PDKProfileSelection) throws(PDKProfileValueError) in
            try w.string(s.requirementID); try w.optional(s.cornerID); try w.strings(s.assetIDs)
            try w.strings(s.sourceKeys); try w.optional(s.selectedSection)
        }
        try w.array(try work.sorted(sources, by: { (lhs, rhs) throws(PDKProfileValueError) in try work.less(lhs.sourceKey, rhs.sourceKey) })) { (w: inout Writer, s: PDKProfileSource) throws(PDKProfileValueError) in
            try w.string(s.sourceKey); try w.optional(s.assetID); try w.reference(s.reference); try w.strings(s.logicalRoutes)
        }
        try w.strings(definition.orderedSearchRoutes)
        try w.array(dependencies) { (w: inout Writer, e: PDKSourceDependency) throws(PDKProfileValueError) in
            try w.string(e.parentSourceKey); try w.reference(e.parentReference); try w.uint(e.statementByteOffset)
            try w.uint(e.statementOrdinal); try w.string(e.directiveKind); try w.string(e.literalRoute)
            try w.string(e.childSourceKey); try w.reference(e.childReference); try w.optional(e.selectedSection)
            try w.string(e.preprocessingIdentity); try w.uint(e.lexicalOrder)
        }
        try w.strings(try work.sorted(mandatorySupportSourceKeys, by: { (lhs: String, rhs: String) throws(PDKProfileValueError) in try work.less(lhs, rhs) }))
        try w.string(definition.inspectionPolicyIdentity)
    }

    public func digest(_ bytes: [UInt8], using digester: any ContentDigesting = SHA256ContentDigester(),
                       resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) -> ContentDigest {
        let work = PDKProfileConstructionWork(resources)
        try work.check()
        let chunkCapacity = min(bytes.count, 4096)
        try work.temporary(UInt8.self, capacity: chunkCapacity)
        var resourceFailure: PDKProfileValueError?
        let result: ContentDigest
        do throws(ContentDigestError) {
            let limits = try ContentDigestSessionLimits(maximumChunkByteCount: UInt64(max(chunkCapacity, 1)),
                maximumTotalByteCount: UInt64(max(bytes.count, 1)), maximumUpdateCount: UInt64(max(bytes.count / 4096 + (bytes.count % 4096 == 0 ? 0 : 1), 1)))
            result = try digester.digest(using: .sha256, limits: limits) { (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in
                var chunk: [UInt8] = []; chunk.reserveCapacity(chunkCapacity)
                var offset = 0
                while offset < bytes.count {
                    let end = offset + min(chunkCapacity, bytes.count - offset)
                    do throws(PDKProfileValueError) { try work.charge(.hashedBytes, UInt64(end - offset)); try work.step(UInt64(end - offset)) }
                    catch { resourceFailure = error; throw .backendUpdateFailed(reason: "Profile resource admission failed") }
                    // The digest boundary accepts owned arrays; retain one bounded cooperative chunk.
                    chunk.removeAll(keepingCapacity: true); chunk.append(contentsOf: bytes[offset..<end])
                    try lease.update(chunk)
                    do throws(PDKProfileValueError) { try work.check() }
                    catch { resourceFailure = error; throw .backendUpdateFailed(reason: "Profile resource admission failed") }
                    offset = end
                }
            }.digest
        } catch {
            if let resourceFailure { throw resourceFailure }
            throw .noncanonicalEncoding("Digest service failed")
        }
        if let resourceFailure { throw resourceFailure }
        try work.check()
        return result
    }

    struct Buffer {
        let bytes: [UInt8]
        let reservations: [PDKAdmissionReservation]
    }
    private struct Writer {
        let sizing: Bool
        let work: PDKProfileConstructionWork
        var bytes: [UInt8] = []
        var byteCount: UInt64 = 0
        mutating func count(_ amount: UInt64) throws(PDKProfileValueError) {
            try work.step()
            let (next, overflow) = byteCount.addingReportingOverflow(amount)
            guard !overflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }; byteCount = next
        }
        mutating func uint(_ value: UInt64) throws(PDKProfileValueError) {
            try count(8)
            if !sizing { for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8(truncatingIfNeeded: value >> shift)) } }
        }
        mutating func string(_ value: String) throws(PDKProfileValueError) {
            let length = try work.byteCount(value)
            try uint(length); try count(length)
            if !sizing {
                for byte in value.utf8 { try work.step(); bytes.append(byte) }
            }
        }
        mutating func bool(_ value: Bool) throws(PDKProfileValueError) { try count(1); if !sizing { bytes.append(value ? 1 : 0) } }
        mutating func optional(_ value: String?) throws(PDKProfileValueError) { try bool(value != nil); if let value { try string(value) } }
        mutating func number(_ value: Double) throws(PDKProfileValueError) { try uint(value == 0 ? 0 : value.bitPattern) }
        mutating func strings(_ values: [String]) throws(PDKProfileValueError) {
            try array(values) { (w: inout Self, s: String) throws(PDKProfileValueError) in try w.string(s) }
        }
        mutating func array<T>(_ values: [T], body: (inout Self, T) throws(PDKProfileValueError) -> Void) throws(PDKProfileValueError) {
            try uint(UInt64(values.count)); for value in values { try work.step(); try body(&self, value) }
        }
        mutating func reference(_ r: ArtifactReference) throws(PDKProfileValueError) {
            try string(r.digest.algorithm.rawValue); try string(r.digest.hexadecimalValue); try uint(r.byteCount)
            try string(r.descriptor.role.rawValue); try string(r.descriptor.kind.rawValue); try string(r.descriptor.format.rawValue)
        }
    }
}
