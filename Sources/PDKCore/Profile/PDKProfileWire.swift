import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
struct PDKProfileWire: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
    static func resources(_ decoder: Decoder) throws(PDKProfileValueError) -> (any PDKAdmissionResourceAccounting)? {
        guard let raw = decoder.userInfo[PDKAdmissionDecodingContext.accountingKey] else { return nil }
        guard let resources = raw as? any PDKAdmissionResourceAccounting else {
            throw .resource(.unsupportedBudgetCapability("Invalid decoder accounting context"))
        }
        return resources
    }
    static func check(_ decoder: Decoder, fields: [String]) throws {
        let work = PDKProfileConstructionWork(try resources(decoder))
        let c = try decoder.container(keyedBy: Self.self)
        try work.temporary(String.self, capacity: fields.count + 1)
        let allowed = fields + ["schemaVersion"]
        for key in c.allKeys {
            try work.step()
            guard try work.contains(allowed, where: { (field) throws(PDKProfileValueError) in try work.equal(field, key.stringValue) }) else {
                throw PDKProfileValueError.noncanonicalEncoding(work.context(key.stringValue))
            }
        }
        for field in allowed {
            try work.step()
            guard c.contains(Self(stringValue: field)) else { throw PDKProfileValueError.noncanonicalEncoding("Missing " + field) }
        }
        let version = try c.decode(Int.self, forKey: Self(stringValue: "schemaVersion"))
        guard version == 1 else { throw PDKProfileValueError.unsupportedSchema(version) }
    }
    static func id(_ value: String, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        let work = PDKProfileConstructionWork(resources)
        for scalar in value.unicodeScalars {
            try work.step()
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) { return }
        }
        throw .invalidID(work.context(value))
    }
    static func unique(_ values: [String], resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        try PDKProfileConstructionWork(resources).unique(values)
    }
    static func pvt(_ pvt: PDKPVTCondition, id: String, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        try Self.id(pvt.process.name, resources: resources)
        try PDKProfileConstructionWork(resources).step()
        guard pvt.voltage.isFinite, pvt.voltage > 0,
              pvt.temperatureCelsius.isFinite, pvt.temperatureCelsius > -273.15 else { throw .invalidPVT(PDKProfileConstructionWork(resources).context(id)) }
    }
    static func reference(_ ref: ArtifactReference, id: String, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        guard ref.digest.algorithm == .sha256 else { throw .conflictingReference(PDKProfileConstructionWork(resources).context(id)) }
    }
    static func literalRoute(_ value: String, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        try id(value, resources: resources)
        let work = PDKProfileConstructionWork(resources)
        guard !value.hasPrefix("/"), !value.hasPrefix("\\") else { throw .invalidRoute(work.context(value)) }
        for byte in value.utf8 { try work.step(); if byte == 0 { throw .invalidRoute(work.context(value)) } }
    }
    static func route(_ value: String, resources: (any PDKAdmissionResourceAccounting)? = nil) throws(PDKProfileValueError) {
        try id(value, resources: resources)
        let work = PDKProfileConstructionWork(resources)
        var length = 0
        var onlyDots = true
        for byte in value.utf8 {
            try work.step()
            guard byte != 0, byte != 92 else { throw .invalidRoute(work.context(value)) }
            if byte == 47 {
                guard length > 0, !(onlyDots && length <= 2) else { throw .invalidRoute(work.context(value)) }
                length = 0; onlyDots = true
            } else { length += 1; if byte != 46 { onlyDots = false } }
        }
        guard length > 0, !(onlyDots && length <= 2) else { throw .invalidRoute(work.context(value)) }
    }
}
