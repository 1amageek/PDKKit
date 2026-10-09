import CircuiteFoundation
import PDKCore

struct PDKStageCanonicalEncoding {
    let work: PDKConsumptionWork
    func digest(profile: ContentDigest, requirement: PDKConsumerRequirement,
                sources: PDKAdmissionCollection<PDKConsumedSource>, corners: PDKAdmissionCollection<PDKProfileCorner>,
                selections: PDKAdmissionCollection<PDKProfileSelection>, mappings: PDKAdmissionCollection<PDKStageMappingRequirement>)
        throws(PDKProfileConsumptionError) -> ContentDigest {
        var sizing = PDKConsumptionCanonicalWriter(sizing: true, work: work)
        try encode(&sizing, profile, requirement, sources, corners, selections, mappings)
        guard let size = Int(exactly: sizing.count) else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        let lease = try work.capacity(UInt8.self, size, dimension: .temporaryBytes)
        defer { withExtendedLifetime(lease) {} }
        var writer = PDKConsumptionCanonicalWriter(sizing: false, work: work); writer.bytes.reserveCapacity(size)
        try encode(&writer, profile, requirement, sources, corners, selections, mappings)
        guard writer.count == sizing.count else { throw .invalidProjection }
        let result = try work.value { () throws(PDKProfileValueError) -> ContentDigest in
            try PDKProfileCanonicalEncoding().digest(writer.bytes, resources: work.resources)
        }
        try work.check(); return result
    }
    private func encode(_ w: inout PDKConsumptionCanonicalWriter, _ profile: ContentDigest, _ r: PDKConsumerRequirement,
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
                try w.dependency(edge)
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
}
