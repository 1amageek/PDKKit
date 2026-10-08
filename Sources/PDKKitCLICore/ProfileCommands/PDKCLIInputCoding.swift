import Foundation
import PDKCore
import PDKDiscovery

/// Custom wire constructors cooperate with the enclosing bounded decoder's owner.
enum PDKCLIInputCoding {
    static func resources(_ decoder: any Decoder) throws -> any PDKAdmissionResourceAccounting {
        guard let value = decoder.userInfo[PDKAdmissionDecodingContext.accountingKey],
              let owner = value as? any PDKAdmissionResourceAccounting else {
            throw PDKAdmissionResourceError.unsupportedBudgetCapability("CLI input requires bounded decoder context")
        }
        try owner.check(); return owner
    }
    static func check<Key: CodingKey>(_ container: KeyedDecodingContainer<Key>, fields: [Key]) throws {
        for key in fields {
            guard container.contains(key) else { throw PDKBoundedDecodeError.missingKey(key.stringValue) }
        }
        guard let schema = fields.first(where: { $0.stringValue == "schemaVersion" }),
              try container.decode(Int.self, forKey: schema) == 1 else {
            throw PDKBoundedDecodeError.unsupportedValue("Unsupported CLI input schema")
        }
    }
    static func work(_ resources: any PDKAdmissionResourceAccounting, _ amount: UInt64 = 1) throws {
        try resources.check()
        if amount > 0 { _ = try resources.reserve(PDKAdmissionCost(dimension: .parserWork, amount: amount)) }
    }
    static func capacity<Element>(_ type: Element.Type, count: Int,
                                  resources: any PDKAdmissionResourceAccounting) throws {
        let (bytes, overflow) = UInt64(count).multipliedReportingOverflow(by: UInt64(MemoryLayout<Element>.stride))
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.liveOwnedBytes) }
        if bytes > 0 { _ = try resources.reserve(PDKAdmissionCost(dimension: .liveOwnedBytes, amount: bytes)) }
    }
    static func id(_ value: String, resources: any PDKAdmissionResourceAccounting) throws {
        try work(resources, UInt64(value.utf8.count) + 1)
        guard value.unicodeScalars.contains(where: { !CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            throw PDKBoundedDecodeError.unsupportedValue("Empty CLI identity")
        }
    }
    static func equal(_ left: String, _ right: String,
                      resources: any PDKAdmissionResourceAccounting) throws -> Bool {
        try work(resources, UInt64(left.utf8.count) + UInt64(right.utf8.count) + 1)
        return left == right
    }
    static func unique(_ values: [String], resources: any PDKAdmissionResourceAccounting) throws {
        for index in values.indices {
            try id(values[index], resources: resources)
            for prior in values[..<index] {
                if try equal(prior, values[index], resources: resources) {
                    throw PDKBoundedDecodeError.unsupportedValue("Duplicate CLI identity")
                }
            }
        }
    }
    static func route(_ value: String, resources: any PDKAdmissionResourceAccounting) throws {
        try id(value, resources: resources)
        var length = 0, dots = true
        for byte in value.utf8 {
            try work(resources)
            guard byte != 0, byte != 92 else { throw PDKBoundedDecodeError.unsupportedValue("Invalid logical route") }
            if byte == 47 {
                guard length > 0, !(dots && length <= 2) else { throw PDKBoundedDecodeError.unsupportedValue("Invalid logical route") }
                length = 0; dots = true
            } else { length += 1; if byte != 46 { dots = false } }
        }
        guard length > 0, !(dots && length <= 2) else { throw PDKBoundedDecodeError.unsupportedValue("Invalid logical route") }
    }
}
