import Foundation
import PDKCore

internal struct PDKJSONValueDecoder: Decoder {
    let document: PDKJSONSyntaxDocument
    let node: Int
    var syntax: PDKJSONSyntax { document.nodes[node] }
    let resources: PDKDecodeResourceAccounting
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    var rejectUnknownFields = false

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .object(let members) = syntax else { throw PDKBoundedDecodeError.typeMismatch(expected: "object") }
        try resources.dictionaryCapacity(members.count, keyStride: MemoryLayout<String>.stride,
            valueStride: MemoryLayout<Int>.stride, growing: false, dimension: .temporaryBytes)
        try resources.capacity(members.count, stride: MemoryLayout<Key>.stride * 2)
        try resources.charge(.parserWork, UInt64(members.count))
        var table: [String: Int] = [:]
        var keys: [Key] = []
        table.reserveCapacity(members.count)
        keys.reserveCapacity(members.count)
        for (key, value) in members {
            try resources.charge(.parserWork, UInt64(key.utf8.count + 1))
            table[key] = value
            if let codingKey = Key(stringValue: key) { keys.append(codingKey) }
            else if rejectUnknownFields { throw PDKBoundedDecodeError.unsupportedValue("Unknown typed field") }
        }
        return KeyedDecodingContainer(PDKJSONKeyedContainer<Key>(decoder: self, members: table, keys: keys))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        guard case .array(let values) = syntax else { throw PDKBoundedDecodeError.typeMismatch(expected: "array") }
        return PDKJSONUnkeyedContainer(decoder: self, values: values)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        PDKJSONSingleContainer(decoder: self)
    }

    func child(_ node: Int, key: any CodingKey) throws -> PDKJSONValueDecoder {
        try resources.check()
        try resources.capacity(codingPath.count + 1, stride: MemoryLayout<any CodingKey>.stride)
        return PDKJSONValueDecoder(document: document, node: node, resources: resources, codingPath: codingPath + [key],
            userInfo: userInfo, rejectUnknownFields: rejectUnknownFields)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try resources.check()
        try resources.capacity(1, stride: MemoryLayout<T>.stride)
        if let collection = T.self as? any PDKJSONCollectionCapacity.Type { try collection.admit(syntax, resources: resources) }
        let result = try T(from: self)
        try resources.check()
        return result
    }
}
