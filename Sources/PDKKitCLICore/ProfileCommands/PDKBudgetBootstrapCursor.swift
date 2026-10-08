/// Cursor state owns no input view; every operation receives a scoped borrow.
internal struct PDKBudgetBootstrapCursor {
    private(set) var position = 0
    private(set) var work: UInt64 = 0

    mutating func next(_ bytes: borrowing Span<UInt8>) throws(PDKBudgetBootstrapError) -> UInt8 {
        guard !Task.isCancelled else { throw .cancelled }
        guard position < bytes.count else { throw .malformedInput }
        let (nextWork, overflow) = work.addingReportingOverflow(1)
        guard !overflow else { throw .arithmeticOverflow }
        work = nextWork
        let value = bytes[position]; position += 1; return value
    }
    mutating func whitespace(_ bytes: borrowing Span<UInt8>) throws(PDKBudgetBootstrapError) {
        while position < bytes.count {
            switch bytes[position] {
            case 9, 10, 13, 32: _ = try next(bytes)
            default: return
            }
        }
    }
    mutating func expect(_ value: UInt8, _ bytes: borrowing Span<UInt8>) throws(PDKBudgetBootstrapError) {
        try whitespace(bytes); guard try next(bytes) == value else { throw .malformedInput }
    }
    mutating func consume(_ value: UInt8, _ bytes: borrowing Span<UInt8>) throws(PDKBudgetBootstrapError) -> Bool {
        try whitespace(bytes)
        guard position < bytes.count, bytes[position] == value else { return false }
        _ = try next(bytes); return true
    }
    mutating func name(_ bytes: borrowing Span<UInt8>) throws(PDKBudgetBootstrapError) -> [UInt8] {
        try expect(34, bytes)
        // Scratch is bounded independently of attacker-provided string length.
        var name: [UInt8] = []; name.reserveCapacity(64)
        while true {
            var byte = try next(bytes)
            if byte == 34 { return name }
            guard name.count < 64 else { throw .unknownField }
            if byte == 92 {
                guard try next(bytes) == 117 else { throw .malformedInput }
                var scalar: UInt16 = 0
                for _ in 0..<4 {
                    let digit = try next(bytes)
                    let value: UInt16
                    switch digit {
                    case 48...57: value = UInt16(digit - 48)
                    case 65...70: value = UInt16(digit - 55)
                    case 97...102: value = UInt16(digit - 87)
                    default: throw .malformedInput
                    }
                    scalar = scalar * 16 + value
                }
                guard scalar < 128 else { throw .unknownField }
                byte = UInt8(scalar)
            }
            guard byte >= 32, byte < 128 else { throw .malformedInput }
            name.append(byte)
        }
    }
    mutating func number(_ bytes: borrowing Span<UInt8>) throws(PDKBudgetBootstrapError) -> UInt64 {
        try whitespace(bytes)
        let first = try next(bytes)
        guard first >= 48, first <= 57 else { throw .malformedInput }
        var value = UInt64(first - 48)
        while position < bytes.count {
            let digit = bytes[position]
            guard digit >= 48, digit <= 57 else { break }
            guard first != 48 else { throw .malformedInput }
            _ = try next(bytes)
            let (multiplied, overflow) = value.multipliedReportingOverflow(by: 10)
            let (added, addOverflow) = multiplied.addingReportingOverflow(UInt64(digit - 48))
            guard !overflow, !addOverflow else { throw .arithmeticOverflow }
            value = added
        }
        return value
    }
    mutating func matches(_ name: [UInt8], _ literal: String) throws(PDKBudgetBootstrapError) -> Bool {
        var index = 0
        for byte in literal.utf8 {
            guard !Task.isCancelled else { throw .cancelled }
            let (nextWork, overflow) = work.addingReportingOverflow(1)
            guard !overflow else { throw .arithmeticOverflow }; work = nextWork
            guard index < name.count, name[index] == byte else { return false }
            index += 1
        }
        return index == name.count
    }
}
