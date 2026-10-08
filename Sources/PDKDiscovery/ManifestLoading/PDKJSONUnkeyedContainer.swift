import Foundation
import PDKCore

internal struct PDKJSONUnkeyedContainer: UnkeyedDecodingContainer {
    let decoder: PDKJSONValueDecoder
    let values: [Int]
    var currentIndex = 0
    var codingPath: [any CodingKey] { decoder.codingPath }
    var count: Int? { values.count }
    var isAtEnd: Bool { currentIndex == values.count }
    mutating func decodeNil() throws -> Bool {
        try decoder.resources.check()
        guard !isAtEnd else { throw PDKBoundedDecodeError.typeMismatch(expected: "array element") }
        if case .null = decoder.document.nodes[values[currentIndex]] { currentIndex += 1; return true }
        return false
    }
    private mutating func child() throws -> PDKJSONValueDecoder {
        guard !isAtEnd else { throw PDKBoundedDecodeError.typeMismatch(expected: "array element") }
        try decoder.resources.capacity(1, stride: MemoryLayout<PDKJSONIndexKey>.stride)
        let child = try decoder.child(values[currentIndex], key: PDKJSONIndexKey(currentIndex))
        currentIndex += 1
        return child
    }
    mutating func decode(_ type: Bool.Type) throws -> Bool { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: String.Type) throws -> String { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try PDKJSONSingleContainer(decoder: child()).decode(type) }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try child().decode(type) }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        try child().container(keyedBy: type)
    }
    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer { try child().unkeyedContainer() }
    mutating func superDecoder() throws -> any Decoder { try child() }
}
