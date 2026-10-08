import PDKCore

/// Only the existing PDK wire families use this decoder; collection backing is
/// admitted before standard-library Decodable allocates it, using the element layout.
internal protocol PDKJSONCollectionCapacity {
    static func admit(_ syntax: PDKJSONSyntax, resources: PDKDecodeResourceAccounting) throws
}

extension Array: PDKJSONCollectionCapacity where Element: Decodable {
    static func admit(_ syntax: PDKJSONSyntax, resources: PDKDecodeResourceAccounting) throws {
        guard case .array(let values) = syntax else { return }
        // Standard Array decode grows geometrically; simultaneous old/new capacity
        // during growth is below four element slots per final element.
        let (capacity, overflow) = values.count.multipliedReportingOverflow(by: 4)
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.liveOwnedBytes) }
        try resources.capacity(capacity, stride: MemoryLayout<Element>.stride, dimension: .liveOwnedBytes)
    }
}

extension Dictionary: PDKJSONCollectionCapacity where Key: Decodable, Value: Decodable {
    static func admit(_ syntax: PDKJSONSyntax, resources: PDKDecodeResourceAccounting) throws {
        guard case .object(let values) = syntax else { return }
        try resources.dictionaryCapacity(values.count, keyStride: MemoryLayout<Key>.stride,
            valueStride: MemoryLayout<Value>.stride, growing: true, dimension: .liveOwnedBytes)
    }
}
