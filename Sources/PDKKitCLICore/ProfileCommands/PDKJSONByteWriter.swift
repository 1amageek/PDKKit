import PDKCore

internal struct PDKJSONByteWriter {
    let context: PDKJSONEncodingContext
    var bytes: [UInt8] = []
    var capacity = 0
    var receipt: PDKAdmissionReservation?

    mutating func ensureCapacity(_ required: Int) throws {
        guard required >= 0 else { throw PDKProfileOutputError.capacityOverflow }
        guard required > capacity else { return }
        let (doubled, overflow) = capacity.multipliedReportingOverflow(by: 2)
        let next = max(required, overflow ? required : doubled)
        let nextReceipt = try context.reserve(.liveOwnedBytes, next)
        try context.work(bytes.count)
        bytes.reserveCapacity(next)
        capacity = next
        receipt = nextReceipt
    }
    mutating func append(_ byte: UInt8) throws {
        try context.work()
        let (required, overflow) = bytes.count.addingReportingOverflow(1)
        guard !overflow else { throw PDKProfileOutputError.capacityOverflow }
        try ensureCapacity(required)
        bytes.append(byte)
    }
    mutating func literal(_ value: String) throws {
        for byte in value.utf8 { try append(byte) }
    }
    mutating func string(_ value: String) throws {
        try append(34)
        for byte in value.utf8 {
            try context.work()
            switch byte {
            case 34: try literal("\\\"")
            case 92: try literal("\\\\")
            case 0..<32:
                try literal("\\u00")
                let high = byte >> 4, low = byte & 15
                try append(high < 10 ? high + 48 : high + 87)
                try append(low < 10 ? low + 48 : low + 87)
            default: try append(byte)
            }
        }
        try append(34)
    }
    mutating func write(_ node: PDKJSONEncodingNode) throws {
        try context.work()
        switch node.kind {
        case .unset: throw PDKProfileOutputError.invalidEncoding
        case .scalar:
            guard let scalar = node.scalar else { throw PDKProfileOutputError.invalidEncoding }
            switch scalar {
            case .null: try literal("null")
            case .bool(let value): try literal(value ? "true" : "false")
            case .string(let value): try string(value)
            case .number(let value): try literal(value)
            }
        case .keyed, .unkeyed:
            let keyed = node.kind == .keyed
            try append(keyed ? 123 : 91)
            for (index, field) in node.fields.enumerated() {
                try context.work()
                if index > 0 { try append(44) }
                if keyed {
                    guard let key = field.key else { throw PDKProfileOutputError.invalidEncoding }
                    try string(key); try append(58)
                }
                try write(field.value)
            }
            try append(keyed ? 125 : 93)
        }
    }
}
