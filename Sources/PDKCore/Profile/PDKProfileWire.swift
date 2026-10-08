import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
struct PDKProfileWire: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
    static func check(_ decoder: Decoder, fields: [String]) throws {
        let c = try decoder.container(keyedBy: Self.self)
        let allowed = Set(fields + ["schemaVersion"])
        for key in c.allKeys where !allowed.contains(key.stringValue) {
            throw PDKProfileValueError.noncanonicalEncoding(key.stringValue)
        }
        for field in allowed where !c.contains(Self(stringValue: field)) {
            throw PDKProfileValueError.noncanonicalEncoding("Missing " + field)
        }
        let version = try c.decode(Int.self, forKey: Self(stringValue: "schemaVersion"))
        guard version == 1 else { throw PDKProfileValueError.unsupportedSchema(version) }
    }
    static func id(_ value: String) throws(PDKProfileValueError) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw .invalidID(value) }
    }
    static func unique(_ values: [String]) throws(PDKProfileValueError) {
        for value in values { try id(value) }
        guard Set(values).count == values.count else { throw .duplicateKey(values.joined(separator: ",")) }
    }
    static func pvt(_ pvt: PDKPVTCondition, id: String) throws(PDKProfileValueError) {
        try Self.id(pvt.process.name)
        guard pvt.voltage.isFinite, pvt.voltage > 0,
              pvt.temperatureCelsius.isFinite, pvt.temperatureCelsius > -273.15 else { throw .invalidPVT(id) }
    }
    static func reference(_ ref: ArtifactReference, id: String) throws(PDKProfileValueError) {
        guard ref.digest.algorithm == .sha256 else { throw .conflictingReference(id) }
    }
    static func literalRoute(_ value: String) throws(PDKProfileValueError) {
        try id(value)
        guard !value.hasPrefix("/"), !value.hasPrefix("\\"), !value.contains("\u{0}") else { throw .invalidRoute(value) }
    }
    static func route(_ value: String) throws(PDKProfileValueError) {
        try id(value)
        guard !value.hasPrefix("/"), !value.contains("\u{0}"), !value.contains("\\"),
              !value.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { throw .invalidRoute(value) }
    }
}
