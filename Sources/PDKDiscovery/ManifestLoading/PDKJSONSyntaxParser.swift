import PDKCore

/// The pointer is borrowed only inside the input owner's synchronous buffer closure.
/// It never escapes into syntax nodes; nodes own admitted strings and containers.
internal struct PDKJSONSyntaxParser {
    let bytes: UnsafeBufferPointer<UInt8>
    let resources: PDKDecodeResourceAccounting
    private var offset = 0

    init(bytes: UnsafeBufferPointer<UInt8>, resources: PDKDecodeResourceAccounting) {
        self.bytes = bytes; self.resources = resources
    }

    private struct Frame {
        let node: Int
        let kind: UInt8
        let nesting: PDKAdmissionReservation
        var state = 0
        var values: [Int] = []
        var members: [(String, Int)] = []
        var pendingKey: String?
    }
    private var nodes: [PDKJSONSyntax] = []
    private var frames: [Frame] = []

    mutating func parse() throws -> PDKJSONSyntaxDocument {
        try resources.check()
        try resources.charge(.parserWork, UInt64(bytes.count))
        let root = try value()
        while !frames.isEmpty {
            try resources.check()
            try whitespace()
            let frame = frames.count - 1
            if frames[frame].kind == 91 {
                switch frames[frame].state {
                case 0 where peek == 93: try finish()
                case 0, 1:
                    let child = try value()
                    try resources.grow(&frames[frame].values)
                    frames[frame].values.append(child)
                    frames[frame].state = 2
                default:
                    if peek == 93 { try finish() }
                    else {
                        guard peek == 44 else { throw malformed("Expected comma or array end") }
                        try advance(); frames[frame].state = 1
                    }
                }
            } else {
                switch frames[frame].state {
                case 0 where peek == 125: try finish()
                case 0, 1:
                    guard peek == 34 else { throw malformed("Expected object key") }
                    let keyOffset = offset
                    try resources.charge(.decodedElements, 1)
                    let key = try string()
                    for (existing, _) in frames[frame].members {
                        try resources.charge(.parserWork, UInt64(existing.utf8.count + key.utf8.count + 1))
                        if existing == key { throw PDKBoundedDecodeError.duplicateKey(byteOffset: keyOffset) }
                    }
                    try whitespace()
                    guard peek == 58 else { throw malformed("Expected colon") }
                    try advance()
                    frames[frame].pendingKey = key
                    frames[frame].state = 2
                case 2:
                    let child = try value()
                    guard let key = frames[frame].pendingKey else { throw malformed("Missing object key") }
                    try resources.grow(&frames[frame].members)
                    frames[frame].members.append((key, child))
                    frames[frame].pendingKey = nil
                    frames[frame].state = 3
                default:
                    if peek == 125 { try finish() }
                    else {
                        guard peek == 44 else { throw malformed("Expected comma or object end") }
                        try advance(); frames[frame].state = 1
                    }
                }
            }
        }
        try whitespace()
        guard offset == bytes.count else { throw malformed("Trailing content") }
        try resources.check()
        return PDKJSONSyntaxDocument(nodes: nodes, root: root)
    }

    private mutating func value() throws -> Int {
        try whitespace()
        try resources.check()
        try resources.charge(.decodedElements, 1)
        guard let byte = peek else { throw malformed("Expected value") }
        let value: PDKJSONSyntax
        switch byte {
        case 123, 91: value = .null
        case 34: value = .string(try string())
        case 116: try literal("true"); value = .boolean(true)
        case 102: try literal("false"); value = .boolean(false)
        case 110: try literal("null"); value = .null
        case 45, 48...57: value = .number(try number())
        default: throw malformed("Invalid value token")
        }
        let index = nodes.count
        try resources.grow(&nodes)
        nodes.append(value)
        if byte == 123 || byte == 91 {
            let nesting = try resources.reserve(PDKAdmissionCost(dimension: .decodeNesting, amount: 1))
            try resources.grow(&frames)
            frames.append(Frame(node: index, kind: byte, nesting: nesting))
            try advance()
        }
        return index
    }

    private mutating func finish() throws {
        let frame = frames.removeLast()
        nodes[frame.node] = frame.kind == 91 ? .array(frame.values) : .object(frame.members)
        try advance()
        withExtendedLifetime(frame.nesting) {}
    }

    private mutating func string() throws -> String {
        try advance()
        let start = offset
        var output: [UInt8] = []
        while let byte = peek {
            if byte == 34 {
                try advance()
                try resources.capacity(output.count, stride: 1, dimension: .liveOwnedBytes)
                try resources.charge(.parserWork, UInt64(output.count))
                guard let result = String(validating: output, as: UTF8.self) else {
                    throw PDKBoundedDecodeError.invalidUTF8(byteOffset: start)
                }
                return result
            }
            guard byte >= 32 else { throw malformed("Control byte in string") }
            if byte != 92 { try append(byte, to: &output); try advance(); continue }
            try advance()
            guard let escaped = peek else { throw malformed("Incomplete escape") }
            try advance()
            switch escaped {
            case 34, 92, 47: try append(escaped, to: &output)
            case 98: try append(8, to: &output)
            case 102: try append(12, to: &output)
            case 110: try append(10, to: &output)
            case 114: try append(13, to: &output)
            case 116: try append(9, to: &output)
            case 117:
                var scalar = try hexQuad()
                if (0xD800...0xDBFF).contains(scalar) {
                    guard peek == 92 else { throw malformed("Missing low surrogate") }; try advance()
                    guard peek == 117 else { throw malformed("Missing low surrogate") }; try advance()
                    let low = try hexQuad()
                    guard (0xDC00...0xDFFF).contains(low) else { throw malformed("Invalid low surrogate") }
                    scalar = 0x10000 + ((scalar - 0xD800) << 10) + low - 0xDC00
                }
                guard let unicode = Unicode.Scalar(scalar) else { throw malformed("Invalid Unicode scalar") }
                // A single scalar is at most four bytes; reserve its exact UTF-8 before append.
                let code = unicode.value
                if code < 0x80 { try append(UInt8(code), to: &output) }
                else if code < 0x800 {
                    try append(UInt8(0xC0 | (code >> 6)), to: &output)
                    try append(UInt8(0x80 | (code & 0x3F)), to: &output)
                } else if code < 0x10000 {
                    try append(UInt8(0xE0 | (code >> 12)), to: &output)
                    try append(UInt8(0x80 | ((code >> 6) & 0x3F)), to: &output)
                    try append(UInt8(0x80 | (code & 0x3F)), to: &output)
                } else {
                    try append(UInt8(0xF0 | (code >> 18)), to: &output)
                    try append(UInt8(0x80 | ((code >> 12) & 0x3F)), to: &output)
                    try append(UInt8(0x80 | ((code >> 6) & 0x3F)), to: &output)
                    try append(UInt8(0x80 | (code & 0x3F)), to: &output)
                }
            default: throw malformed("Invalid escape")
            }
        }
        throw malformed("Unterminated string")
    }

    private mutating func hexQuad() throws -> UInt32 {
        var result: UInt32 = 0
        for _ in 0..<4 {
            guard let byte = peek else { throw malformed("Incomplete Unicode escape") }
            let digit: UInt32
            switch byte {
            case 48...57: digit = UInt32(byte - 48)
            case 65...70: digit = UInt32(byte - 55)
            case 97...102: digit = UInt32(byte - 87)
            default: throw malformed("Invalid Unicode escape")
            }
            result = (result << 4) | digit
            try advance()
        }
        return result
    }

    private mutating func number() throws -> String {
        let start = offset
        if peek == 45 { try advance() }
        if peek == 48 { try advance() }
        else {
            guard let digit = peek, (49...57).contains(digit) else { throw malformed("Invalid number") }
            try digits()
        }
        if peek == 46 {
            try advance()
            guard let digit = peek, (48...57).contains(digit) else { throw malformed("Missing fraction") }
            try digits()
        }
        if peek == 101 || peek == 69 {
            try advance()
            if peek == 43 || peek == 45 { try advance() }
            guard let digit = peek, (48...57).contains(digit) else { throw malformed("Missing exponent") }
            try digits()
        }
        let count = offset - start
        try resources.charge(.scalarBytes, UInt64(count))
        try resources.capacity(count, stride: 1)
        try resources.charge(.parserWork, UInt64(count))
        let result = String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<offset]), as: UTF8.self)
        try resources.capacity(count + 1, stride: 1)
        try resources.charge(.parserWork, UInt64(count))
        guard let finite = Double(result), finite.isFinite else { throw PDKBoundedDecodeError.invalidNumber }
        return result
    }

    private mutating func digits() throws {
        while let digit = peek, (48...57).contains(digit) { try advance() }
    }

    private mutating func literal(_ literal: StaticString) throws {
        for index in 0..<literal.utf8CodeUnitCount {
            guard peek == literal.utf8Start[index] else { throw malformed("Invalid literal") }
            try advance()
        }
    }

    private mutating func append(_ byte: UInt8, to output: inout [UInt8]) throws {
        try resources.charge(.scalarBytes, 1)
        try resources.grow(&output)
        output.append(byte)
    }

    private var peek: UInt8? { offset < bytes.count ? bytes[offset] : nil }
    private mutating func advance() throws {
        offset += 1
        if offset % 256 == 0 { try resources.check() }
    }
    private mutating func whitespace() throws {
        while let byte = peek, byte == 32 || byte == 9 || byte == 10 || byte == 13 { try advance() }
    }
    private func malformed(_ reason: String) -> PDKBoundedDecodeError {
        .malformed(byteOffset: offset, reason: reason)
    }
}
