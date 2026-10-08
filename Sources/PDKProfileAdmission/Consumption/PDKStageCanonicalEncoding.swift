import CircuiteFoundation
import PDKCore

struct PDKStageCanonicalEncoding {
    let work: PDKConsumptionWork
    func digest(profile: ContentDigest, requirement: PDKConsumerRequirement,
                sources: PDKAdmissionCollection<PDKConsumedSource>, corners: PDKAdmissionCollection<PDKProfileCorner>,
                selections: PDKAdmissionCollection<PDKProfileSelection>, mappings: PDKAdmissionCollection<PDKStageMappingRequirement>)
        throws(PDKProfileConsumptionError) -> ContentDigest {
        var sizing = Writer(sizing: true, work: work)
        try encode(&sizing, profile, requirement, sources, corners, selections, mappings)
        guard let size = Int(exactly: sizing.count) else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        let lease = try work.capacity(UInt8.self, size, dimension: .temporaryBytes)
        defer { withExtendedLifetime(lease) {} }
        var writer = Writer(sizing: false, work: work); writer.bytes.reserveCapacity(size)
        try encode(&writer, profile, requirement, sources, corners, selections, mappings)
        guard writer.count == sizing.count else { throw .invalidProjection }
        let result = try work.value { () throws(PDKProfileValueError) -> ContentDigest in
            try PDKProfileCanonicalEncoding().digest(writer.bytes, resources: work.resources)
        }
        try work.check(); return result
    }
    private func encode(_ w: inout Writer, _ profile: ContentDigest, _ r: PDKConsumerRequirement,
                        _ sources: PDKAdmissionCollection<PDKConsumedSource>, _ corners: PDKAdmissionCollection<PDKProfileCorner>,
                        _ selections: PDKAdmissionCollection<PDKProfileSelection>, _ mappings: PDKAdmissionCollection<PDKStageMappingRequirement>)
        throws(PDKProfileConsumptionError) {
        try w.string("PDKKit.Profile.StageProjection"); try w.uint(1)
        try w.string(profile.algorithm.rawValue); try w.string(profile.hexadecimalValue)
        try w.string(r.stageID); try w.string(r.configurationIdentity); try w.strings(r.requirementIDs); try w.strings(r.cornerIDs)
        try w.uint(UInt64(corners.count))
        for corner in corners {
            try w.string(corner.cornerID); try w.string(corner.pvt.process.name); try w.bool(corner.pvt.process.nominal)
            try w.number(corner.pvt.voltage); try w.number(corner.pvt.temperatureCelsius)
        }
        try w.uint(UInt64(selections.count))
        for selection in selections {
            try w.string(selection.requirementID); try w.optional(selection.cornerID)
            try w.strings(selection.assetIDs); try w.strings(selection.sourceKeys); try w.optional(selection.selectedSection)
        }
        try w.uint(UInt64(sources.count))
        for source in sources {
            try w.uint(source.occurrenceID); try w.string(source.sourceKey); try w.reference(source.reference)
            try w.optional(source.cornerID); try w.optional(source.selectedSection); try w.string(source.preprocessingIdentity)
            try w.bool(source.parentOccurrenceID != nil)
            if let parent = source.parentOccurrenceID { try w.uint(parent) }
            try w.bool(source.incomingDependency != nil)
            if let edge = source.incomingDependency {
                try w.string(edge.parentSourceKey); try w.reference(edge.parentReference)
                try w.uint(edge.statementByteOffset); try w.uint(edge.statementOrdinal)
                try w.string(edge.directiveKind); try w.string(edge.literalRoute)
                try w.string(edge.childSourceKey); try w.reference(edge.childReference)
                try w.optional(edge.selectedSection); try w.string(edge.preprocessingIdentity); try w.uint(edge.lexicalOrder)
            }
        }
        try w.uint(UInt64(mappings.count))
        for mapping in mappings {
            try w.uint(mapping.rootOccurrenceID)
            switch mapping.condition {
            case .factKind(let kind): try w.uint(0); try w.string(kind)
            case .name(let name): try w.uint(1); try w.string(name)
            case .layer(let layer):
                try w.uint(2); try w.string(layer.name)
                guard let number = Int64(exactly: layer.number) else { throw .resource(.arithmeticOverflow(.parserWork)) }
                try w.uint(UInt64(bitPattern: number)); try w.string(layer.purpose.rawValue)
            case .device(let device):
                try w.uint(3); try w.string(device.modelName); try w.uint(UInt64(device.terminals.count))
                for terminal in device.terminals {
                    guard let order = UInt64(exactly: terminal.order) else { throw .invalidProjection }
                    try w.uint(order); try w.string(terminal.name)
                }
            }
        }
    }
    private struct Writer {
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
        mutating func number(_ value: Double) throws(PDKProfileConsumptionError) { try uint(value == 0 ? 0 : value.bitPattern) }
    }
}
