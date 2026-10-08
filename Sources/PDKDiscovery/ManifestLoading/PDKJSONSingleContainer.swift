import Foundation
import PDKCore

internal struct PDKJSONSingleContainer: SingleValueDecodingContainer {
    let decoder: PDKJSONValueDecoder
    var codingPath: [any CodingKey] { decoder.codingPath }
    func decodeNil() -> Bool { if case .null = decoder.syntax { return true }; return false }
    func decode(_ type: Bool.Type) throws -> Bool {
        try decoder.resources.check()
        guard case .boolean(let value) = decoder.syntax else { throw PDKBoundedDecodeError.typeMismatch(expected: "boolean") }
        return value
    }
    func decode(_ type: String.Type) throws -> String {
        try decoder.resources.check()
        guard case .string(let value) = decoder.syntax else { throw PDKBoundedDecodeError.typeMismatch(expected: "string") }
        // The parser admitted this immutable string backing as owned storage.
        return value
    }
    func decode(_ type: Double.Type) throws -> Double {
        let raw = try number()
        try decoder.resources.capacity(raw.utf8.count + 1, stride: 1)
        guard let value = Double(raw), value.isFinite else { throw PDKBoundedDecodeError.invalidNumber }
        return value
    }
    func decode(_ type: Float.Type) throws -> Float {
        let raw = try number()
        try decoder.resources.capacity(raw.utf8.count + 1, stride: 1)
        guard let value = Float(raw), value.isFinite else { throw PDKBoundedDecodeError.invalidNumber }
        return value
    }
    private func number() throws -> String {
        try decoder.resources.check()
        guard case .number(let raw) = decoder.syntax else { throw PDKBoundedDecodeError.typeMismatch(expected: "number") }
        try decoder.resources.charge(.parserWork, UInt64(raw.utf8.count + 1))
        return raw
    }
    func decode(_ type: Int.Type) throws -> Int { try integer(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try integer(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try integer(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try integer(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try integer(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try integer(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try integer(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try integer(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try integer(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try integer(type) }
    private func integer<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let raw = try number()
        try decoder.resources.capacity(raw.utf8.count, stride: 1)
        var digits: [UInt8] = []
        digits.reserveCapacity(raw.utf8.count)
        var negative = false
        var fractional = false
        var fractionCount = 0
        var exponent = 0
        var exponentNegative = false
        var inExponent = false
        for byte in raw.utf8 {
            try decoder.resources.check()
            if byte == 45 {
                if inExponent { exponentNegative = true } else { negative = true }
            } else if byte == 46 { fractional = true }
            else if byte == 101 || byte == 69 { inExponent = true }
            else if byte == 43 { continue }
            else if inExponent {
                let (times, overflow) = exponent.multipliedReportingOverflow(by: 10)
                let (sum, addOverflow) = times.addingReportingOverflow(Int(byte - 48))
                guard !overflow, !addOverflow else { throw PDKBoundedDecodeError.invalidNumber }
                exponent = sum
            } else {
                digits.append(byte)
                if fractional { fractionCount += 1 }
            }
        }
        var allZero = true
        for digit in digits {
            try decoder.resources.charge(.parserWork, 1)
            if digit != 48 { allZero = false }
        }
        if allZero { return 0 }
        if exponentNegative { exponent = -exponent }
        let (adjusted, overflow) = exponent.subtractingReportingOverflow(fractionCount)
        guard !overflow else { throw PDKBoundedDecodeError.invalidNumber }
        var scale = adjusted
        while digits.last == 48 {
            try decoder.resources.charge(.parserWork, 1)
            digits.removeLast()
            let (next, overflow) = scale.addingReportingOverflow(1)
            guard !overflow else { throw PDKBoundedDecodeError.invalidNumber }
            scale = next
        }
        guard scale >= 0, scale <= type.bitWidth else { throw PDKBoundedDecodeError.invalidNumber }
        if negative, !T.isSigned { throw PDKBoundedDecodeError.invalidNumber }
        var value: T = 0
        for byte in digits {
            try decoder.resources.charge(.parserWork, 1)
            let (times, overflow) = value.multipliedReportingOverflow(by: 10)
            let (next, addOverflow) = negative ? times.subtractingReportingOverflow(T(byte - 48)) : times.addingReportingOverflow(T(byte - 48))
            guard !overflow, !addOverflow else { throw PDKBoundedDecodeError.invalidNumber }
            value = next
        }
        for _ in 0..<scale {
            try decoder.resources.charge(.parserWork, 1)
            let (next, overflow) = value.multipliedReportingOverflow(by: 10)
            guard !overflow else { throw PDKBoundedDecodeError.invalidNumber }
            value = next
        }
        return value
    }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try decoder.decode(type) }
}
