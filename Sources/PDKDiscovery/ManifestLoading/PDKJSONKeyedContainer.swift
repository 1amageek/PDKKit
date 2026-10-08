import Foundation
import PDKCore

internal struct PDKJSONKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: PDKJSONValueDecoder
    let members: [String: Int]
    var codingPath: [any CodingKey] { decoder.codingPath }
    let keys: [Key]
    var allKeys: [Key] { keys }
    func contains(_ key: Key) -> Bool { members[key.stringValue] != nil }
    func decodeNil(forKey key: Key) throws -> Bool {
        let value = try value(key)
        if case .null = decoder.document.nodes[value] { return true }
        return false
    }
    private func value(_ key: Key) throws -> Int {
        try decoder.resources.check()
        try decoder.resources.charge(.parserWork, UInt64(key.stringValue.utf8.count + 1))
        guard let value = members[key.stringValue] else { throw PDKBoundedDecodeError.missingKey(key.stringValue) }
        return value
    }
    private func child(_ key: Key) throws -> PDKJSONValueDecoder { try decoder.child(value(key), key: key) }
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try PDKJSONSingleContainer(decoder: child(key)).decode(type) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T { try child(key).decode(type) }
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        try child(key).container(keyedBy: type)
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer { try child(key).unkeyedContainer() }
    func superDecoder() throws -> any Decoder { throw PDKBoundedDecodeError.unsupportedValue("Inheritance decoder") }
    func superDecoder(forKey key: Key) throws -> any Decoder { try child(key) }
}
