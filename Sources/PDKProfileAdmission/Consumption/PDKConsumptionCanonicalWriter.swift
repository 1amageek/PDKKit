import CircuiteFoundation
import PDKCore

struct PDKConsumptionCanonicalWriter {
        let sizing: Bool
        let work: PDKConsumptionWork
        var count: UInt64 = 0
        var bytes: [UInt8] = []
        mutating func grow(_ amount: UInt64) throws(PDKProfileConsumptionError) {
            try work.step(); let (next, overflow) = count.addingReportingOverflow(amount)
            guard !overflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }; count = next
        }
        mutating func uint(_ value: UInt64) throws(PDKProfileConsumptionError) {
            try grow(8)
            if !sizing {
                for shift in stride(from: 56, through: 0, by: -8) { try work.step(); bytes.append(UInt8(truncatingIfNeeded: value >> shift)) }
            }
        }
        mutating func bool(_ value: Bool) throws(PDKProfileConsumptionError) {
            try grow(1); if !sizing { bytes.append(value ? 1 : 0) }
        }
        mutating func string(_ value: String) throws(PDKProfileConsumptionError) {
            let size = try work.bytes(value); try uint(size); try grow(size)
            if !sizing { for byte in value.utf8 { try work.step(); bytes.append(byte) } }
        }
        mutating func optional(_ value: String?) throws(PDKProfileConsumptionError) {
            try bool(value != nil); if let value { try string(value) }
        }
        mutating func strings(_ values: [String]) throws(PDKProfileConsumptionError) {
            try uint(UInt64(values.count)); for value in values { try string(value) }
        }
        mutating func reference(_ value: ArtifactReference) throws(PDKProfileConsumptionError) {
            try string(value.digest.algorithm.rawValue); try string(value.digest.hexadecimalValue); try uint(value.byteCount)
            try string(value.descriptor.role.rawValue); try string(value.descriptor.kind.rawValue); try string(value.descriptor.format.rawValue)
        }
        mutating func dependency(_ edge: PDKSourceDependency) throws(PDKProfileConsumptionError) {
            try string(edge.parentSourceKey); try reference(edge.parentReference)
            try uint(edge.statementByteOffset); try uint(edge.statementOrdinal)
            try string(edge.directiveKind); try string(edge.literalRoute)
            try string(edge.childSourceKey); try reference(edge.childReference)
            try optional(edge.selectedSection); try string(edge.preprocessingIdentity); try uint(edge.lexicalOrder)
        }
        mutating func number(_ value: Double) throws(PDKProfileConsumptionError) { try uint(value == 0 ? 0 : value.bitPattern) }
    }
