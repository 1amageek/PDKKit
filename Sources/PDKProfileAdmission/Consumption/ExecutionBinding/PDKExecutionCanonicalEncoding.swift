import CircuiteFoundation
import PDKCore

struct PDKExecutionCanonicalEncoding {
    let work: PDKConsumptionWork
    func digest(projection: ContentDigest, input: ContentDigest,
                bindings: PDKAdmissionCollection<PDKExecutionSourceBinding>, entries: PDKAdmissionCollection<PDKExecutionEntry>)
        throws(PDKProfileConsumptionError) -> ContentDigest {
        var sizing = PDKConsumptionCanonicalWriter(sizing: true, work: work)
        try encode(&sizing, projection, input, bindings, entries)
        guard let size = Int(exactly: sizing.count) else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        let lease = try work.capacity(UInt8.self, size, dimension: .temporaryBytes)
        defer { withExtendedLifetime(lease) {} }
        var writer = PDKConsumptionCanonicalWriter(sizing: false, work: work)
        writer.bytes.reserveCapacity(size)
        try encode(&writer, projection, input, bindings, entries)
        guard writer.count == sizing.count else { throw .invalidProjection }
        let result = try work.value { () throws(PDKProfileValueError) -> ContentDigest in
            try PDKProfileCanonicalEncoding().digest(writer.bytes, resources: work.resources)
        }
        try work.check(); return result
    }
    private func encode(_ writer: inout PDKConsumptionCanonicalWriter, _ projection: ContentDigest, _ input: ContentDigest,
                        _ bindings: PDKAdmissionCollection<PDKExecutionSourceBinding>, _ entries: PDKAdmissionCollection<PDKExecutionEntry>)
        throws(PDKProfileConsumptionError) {
        try writer.string("PDKKit.Profile.ExecutionBinding"); try writer.uint(1)
        try writer.string(projection.algorithm.rawValue); try writer.string(projection.hexadecimalValue)
        try writer.string(input.algorithm.rawValue); try writer.string(input.hexadecimalValue)
        try writer.uint(UInt64(bindings.count))
        for binding in bindings { try writer.uint(binding.profileOccurrenceID); try writer.uint(binding.executionOccurrenceID) }
        try writer.uint(UInt64(entries.count))
        for entry in entries {
            try writer.uint(entry.profileRootOccurrenceID); try writer.uint(entry.executionRootOccurrenceID)
            try writer.bool(entry.externalParentOccurrenceID != nil)
            if let parent = entry.externalParentOccurrenceID, let reference = entry.externalParentReference, let edge = entry.incomingDependency {
                try writer.uint(parent); try writer.reference(reference); try writer.dependency(edge)
            }
        }
    }
}
