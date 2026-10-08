import CircuiteFoundation
import CircuiteFoundationCrypto

/// Encoding v1: unsigned 64-bit big-endian counts, framed UTF-8, one-byte optional
/// tags, IEEE-754 binary64 big-endian finite numbers with zero normalized.
/// Sets sort by stable IDs; explicit source precedence and lexical edges retain order.
public struct PDKProfileCanonicalEncoding: Sendable {
    public static let version: UInt64 = 1
    public init() {}

    func bytes(definitionReference: ArtifactReference, definition: PDKProfileDefinition,
                      corners: [PDKProfileCorner], selections: [PDKProfileSelection],
                      sources: [PDKProfileSource], dependencies: [PDKSourceDependency],
                      mandatorySupportSourceKeys: [String]) -> [UInt8] {
        var w = Writer()
        w.string("PDKKit.Profile.Selection")
        w.uint(Self.version)
        w.reference(definitionReference)
        w.reference(definition.manifestReference)
        w.string(definition.profileID); w.string(definition.processID); w.string(definition.version)
        w.strings(definition.requiredCornerIDs.sorted())
        w.array(definition.requirements.sorted { $0.requirementID < $1.requirementID }) { w, r in
            w.string(r.requirementID); w.string(r.purposeID); w.string(r.view.rawValue); w.string(r.role.rawValue)
            w.strings(r.allowsMultipleSources ? r.assetIDs : r.assetIDs.sorted()); w.strings(r.cornerIDs.sorted()); w.optional(r.selectedSection)
            w.bool(r.isShared); w.bool(r.allowsMultipleSources); w.strings(r.demandedFactKinds.sorted())
        }
        w.array(corners.sorted { $0.cornerID < $1.cornerID }) { w, c in
            w.string(c.cornerID); w.string(c.pvt.process.name); w.bool(c.pvt.process.nominal)
            w.number(c.pvt.voltage); w.number(c.pvt.temperatureCelsius)
        }
        w.array(selections.sorted { ($0.requirementID, $0.cornerID ?? "") < ($1.requirementID, $1.cornerID ?? "") }) { w, s in
            w.string(s.requirementID); w.optional(s.cornerID); w.strings(s.assetIDs)
            w.strings(s.sourceKeys); w.optional(s.selectedSection)
        }
        w.array(sources.sorted { $0.sourceKey < $1.sourceKey }) { w, s in
            w.string(s.sourceKey); w.optional(s.assetID); w.reference(s.reference); w.strings(s.logicalRoutes)
        }
        w.strings(definition.orderedSearchRoutes)
        w.array(dependencies) { w, e in
            w.string(e.parentSourceKey); w.reference(e.parentReference); w.uint(e.statementByteOffset)
            w.uint(e.statementOrdinal); w.string(e.directiveKind); w.string(e.literalRoute)
            w.string(e.childSourceKey); w.reference(e.childReference); w.optional(e.selectedSection)
            w.string(e.preprocessingIdentity); w.uint(e.lexicalOrder)
        }
        w.strings(mandatorySupportSourceKeys.sorted())
        w.string(definition.inspectionPolicyIdentity)
        return w.bytes
    }

    public func digest(_ bytes: [UInt8], using digester: any ContentDigesting = SHA256ContentDigester()) throws -> ContentDigest {
        try digester.digest(using: .sha256, limits: .singleBufferMaximum) { (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in
            try lease.update(bytes)
        }.digest
    }

    private struct Writer {
        var bytes: [UInt8] = []
        mutating func uint(_ value: UInt64) {
            for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8(truncatingIfNeeded: value >> shift)) }
        }
        mutating func string(_ value: String) { uint(UInt64(value.utf8.count)); bytes.append(contentsOf: value.utf8) }
        mutating func bool(_ value: Bool) { bytes.append(value ? 1 : 0) }
        mutating func optional(_ value: String?) { bool(value != nil); if let value { string(value) } }
        mutating func number(_ value: Double) { uint(value == 0 ? 0 : value.bitPattern) }
        mutating func strings(_ values: [String]) { array(values) { $0.string($1) } }
        mutating func array<T>(_ values: [T], body: (inout Self, T) -> Void) {
            uint(UInt64(values.count)); for value in values { body(&self, value) }
        }
        mutating func reference(_ r: ArtifactReference) {
            string(r.digest.algorithm.rawValue); string(r.digest.hexadecimalValue); uint(r.byteCount)
            string(r.descriptor.role.rawValue); string(r.descriptor.kind.rawValue); string(r.descriptor.format.rawValue)
        }
    }
}
