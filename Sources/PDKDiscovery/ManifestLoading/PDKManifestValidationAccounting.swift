import PDKCore

/// Adapts Core's rule construction events to the existing decode lease owner.
internal struct PDKManifestValidationAccounting {
    let resources: PDKDecodeResourceAccounting

    func admit(_ event: PDKManifestValidationEvent) throws {
        try resources.check()
        switch event {
        case .checkpoint:
            try resources.charge(.parserWork, 1)
        case .work(let count):
            try resources.charge(.parserWork, UInt64(count))
        case .inspect(let string):
            try resources.charge(.parserWork, sum(UInt64(string.utf8.count), 1, dimension: .parserWork))
        case .projection(let count):
            try resources.charge(.parserWork, UInt64(count))
            try resources.capacity(count, stride: MemoryLayout<String>.stride)
        case .identifierSet(let count):
            // Swift 6.4 Native Set and Dictionary use the same 3/4-load hash table;
            // Set has element buckets and occupancy words, with no value array.
            try resources.dictionaryCapacity(count, keyStride: MemoryLayout<String>.stride,
                valueStride: 0, growing: false, dimension: .temporaryBytes)
        case .findingGrowth(let capacity):
            let (next, overflow) = max(capacity, 1).multipliedReportingOverflow(by: 2)
            guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.liveOwnedBytes) }
            // Earlier reservations remain alive while the replacement buffer grows.
            try resources.capacity(next, stride: MemoryLayout<PDKValidationFinding>.stride, dimension: .liveOwnedBytes)
        case .findingActions:
            try resources.capacity(1, stride: MemoryLayout<String>.stride, dimension: .liveOwnedBytes)
        case .diagnostic(let finding):
            try resources.charge(.diagnosticEntries, 1)
            var bytes = try sum(UInt64(finding.code.utf8.count), UInt64(finding.message.utf8.count), dimension: .diagnosticBytes)
            bytes = try sum(bytes, UInt64(finding.entity?.utf8.count ?? 0), dimension: .diagnosticBytes)
            for action in finding.suggestedActions {
                bytes = try sum(bytes, UInt64(action.utf8.count), dimension: .diagnosticBytes)
            }
            try resources.charge(.diagnosticBytes, bytes)
        case .temporaryText(let count):
            try resources.capacity(count, stride: MemoryLayout<UInt8>.stride)
        case .retainedText(let count):
            try resources.charge(.scalarBytes, UInt64(count))
            try resources.capacity(count, stride: MemoryLayout<UInt8>.stride, dimension: .liveOwnedBytes)
        case .joinedEntity(let first, let second):
            let bytes = try sum(sum(UInt64(first), UInt64(second), dimension: .liveOwnedBytes), 1, dimension: .liveOwnedBytes)
            try resources.charge(.scalarBytes, bytes)
            try resources.charge(.liveOwnedBytes, bytes)
        }
        try resources.check()
    }

    private func sum(_ first: UInt64, _ second: UInt64, dimension: PDKAdmissionResourceDimension) throws -> UInt64 {
        let (result, overflow) = first.addingReportingOverflow(second)
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(dimension) }
        return result
    }
}
