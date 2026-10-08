import Foundation

internal final class PDKCooperativeJSONEncoder: Encoder {
    let context: PDKJSONEncodingContext
    let node: PDKJSONEncodingNode
    let codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    init(context: PDKJSONEncodingContext, node: PDKJSONEncodingNode, codingPath: [any CodingKey] = []) {
        self.context = context; self.node = node; self.codingPath = codingPath
    }
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        context.record { try node.select(.keyed) }
        return KeyedEncodingContainer(Keyed<Key>(encoder: self))
    }
    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        context.record { try node.select(.unkeyed) }
        return Unkeyed(encoder: self)
    }
    func singleValueContainer() -> any SingleValueEncodingContainer { Single(encoder: self) }

    func child(key: any CodingKey, keyed: Bool) throws -> PDKCooperativeJSONEncoder {
        try context.check()
        try context.work()
        let child = try node.append(key: keyed ? key.stringValue : nil, context: context)
        let (count, overflow) = codingPath.count.addingReportingOverflow(1)
        guard !overflow else { throw PDKProfileOutputError.capacityOverflow }
        try context.temporary(context.bytes(for: (any CodingKey).self, count: count))
        try context.work(codingPath.count)
        var path: [any CodingKey] = []
        path.reserveCapacity(count)
        path.append(contentsOf: codingPath); path.append(key)
        return PDKCooperativeJSONEncoder(context: context, node: child, codingPath: path)
    }
    func nonthrowingChild(key: any CodingKey, keyed: Bool) -> PDKCooperativeJSONEncoder {
        do { return try child(key: key, keyed: keyed) }
        catch { context.failure = .preserving(error); return self }
    }
    func scalar(_ value: PDKJSONEncodingNode.Scalar) throws {
        try context.check(); try context.work()
        guard node.kind == .unset else { throw PDKProfileOutputError.invalidEncoding }
        node.kind = .scalar; node.scalar = value
    }
    func number(_ make: @autoclosure () -> String) throws {
        try context.temporary(32); try context.work(32)
        try scalar(.number(make()))
    }
    struct PathKey: CodingKey {
        let stringValue: String
        let intValue: Int?
        init(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init(intValue: Int) { self.stringValue = "Index"; self.intValue = intValue }
    }

    struct Keyed<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let encoder: PDKCooperativeJSONEncoder
        var codingPath: [any CodingKey] { encoder.codingPath }
        func child(_ key: Key) throws -> PDKCooperativeJSONEncoder { try encoder.child(key: key, keyed: true) }
        mutating func encodeNil(forKey key: Key) throws { try child(key).scalar(.null) }
        mutating func encode(_ value: Bool, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: String, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: Double, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: Float, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: Int, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: Int8, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: Int16, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: Int32, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: Int64, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: UInt, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: UInt8, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: UInt16, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: UInt32, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode(_ value: UInt64, forKey key: Key) throws { try Single(encoder: child(key)).encode(value) }
        mutating func encode<Value: Encodable>(_ value: Value, forKey key: Key) throws {
            let next = try child(key); try value.encode(to: next); try encoder.context.check()
        }
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
            encoder.nonthrowingChild(key: key, keyed: true).container(keyedBy: type)
        }
        mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
            encoder.nonthrowingChild(key: key, keyed: true).unkeyedContainer()
        }
        mutating func superEncoder() -> any Encoder {
            encoder.nonthrowingChild(key: PathKey(stringValue: "super"), keyed: true)
        }
        mutating func superEncoder(forKey key: Key) -> any Encoder { encoder.nonthrowingChild(key: key, keyed: true) }
    }

    struct Unkeyed: UnkeyedEncodingContainer {
        let encoder: PDKCooperativeJSONEncoder
        var codingPath: [any CodingKey] { encoder.codingPath }
        var count: Int { encoder.node.fields.count }
        func child() throws -> PDKCooperativeJSONEncoder { try encoder.child(key: PathKey(intValue: count), keyed: false) }
        mutating func encodeNil() throws { try child().scalar(.null) }
        mutating func encode(_ value: Bool) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: String) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: Double) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: Float) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: Int) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: Int8) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: Int16) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: Int32) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: Int64) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: UInt) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: UInt8) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: UInt16) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: UInt32) throws { try Single(encoder: child()).encode(value) }
        mutating func encode(_ value: UInt64) throws { try Single(encoder: child()).encode(value) }
        mutating func encode<Value: Encodable>(_ value: Value) throws {
            let next = try child(); try value.encode(to: next); try encoder.context.check()
        }
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
            encoder.nonthrowingChild(key: PathKey(intValue: count), keyed: false).container(keyedBy: type)
        }
        mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
            encoder.nonthrowingChild(key: PathKey(intValue: count), keyed: false).unkeyedContainer()
        }
        mutating func superEncoder() -> any Encoder { encoder.nonthrowingChild(key: PathKey(intValue: count), keyed: false) }
    }

    struct Single: SingleValueEncodingContainer {
        let encoder: PDKCooperativeJSONEncoder
        var codingPath: [any CodingKey] { encoder.codingPath }
        func encodeNil() throws { try encoder.scalar(.null) }
        func encode(_ value: Bool) throws { try encoder.scalar(.bool(value)) }
        func encode(_ value: String) throws { try encoder.scalar(.string(value)) }
        func encode(_ value: Double) throws { guard value.isFinite else { throw PDKProfileOutputError.nonFiniteNumber }; try encoder.number(String(value)) }
        func encode(_ value: Float) throws { guard value.isFinite else { throw PDKProfileOutputError.nonFiniteNumber }; try encoder.number(String(value)) }
        func encode(_ value: Int) throws { try encoder.number(String(value)) }
        func encode(_ value: Int8) throws { try encoder.number(String(value)) }
        func encode(_ value: Int16) throws { try encoder.number(String(value)) }
        func encode(_ value: Int32) throws { try encoder.number(String(value)) }
        func encode(_ value: Int64) throws { try encoder.number(String(value)) }
        func encode(_ value: UInt) throws { try encoder.number(String(value)) }
        func encode(_ value: UInt8) throws { try encoder.number(String(value)) }
        func encode(_ value: UInt16) throws { try encoder.number(String(value)) }
        func encode(_ value: UInt32) throws { try encoder.number(String(value)) }
        func encode(_ value: UInt64) throws { try encoder.number(String(value)) }
        func encode<Value: Encodable>(_ value: Value) throws {
            try encoder.context.work()
            try value.encode(to: encoder)
            try encoder.context.check()
        }
    }
}
