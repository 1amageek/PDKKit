import PDKCore

internal final class PDKJSONEncodingNode {
    enum Kind { case unset, scalar, keyed, unkeyed }
    enum Scalar { case null, bool(Bool), string(String), number(String) }
    struct Field { let key: String?; let value: PDKJSONEncodingNode }
    var kind = Kind.unset
    var scalar: Scalar?
    var fields: [Field] = []
    private var capacity = 0
    private var fieldReceipt: PDKAdmissionReservation?
    private let nodeReceipt: PDKAdmissionReservation?

    private init(receipt: PDKAdmissionReservation?) { nodeReceipt = receipt }
    static func make(context: PDKJSONEncodingContext) throws -> PDKJSONEncodingNode {
        let receipt = try context.reserve(.temporaryBytes,
            MemoryLayout<(Kind, Scalar?, [Field], Int, PDKAdmissionReservation?, PDKAdmissionReservation?)>.stride
                + MemoryLayout<(PDKJSONEncodingContext, PDKJSONEncodingNode, [any CodingKey])>.stride)
        try context.work()
        return PDKJSONEncodingNode(receipt: receipt)
    }
    func select(_ kind: Kind) throws {
        guard self.kind == .unset || self.kind == kind else { throw PDKProfileOutputError.invalidEncoding }
        self.kind = kind
    }
    func append(key: String?, context: PDKJSONEncodingContext) throws -> PDKJSONEncodingNode {
        try context.check()
        if let key {
            for field in fields {
                try context.work(key.utf8.count + (field.key?.utf8.count ?? 0) + 1)
                guard field.key != key else { throw PDKProfileOutputError.invalidEncoding }
            }
        }
        if fields.count == capacity {
            let (doubled, overflow) = capacity.multipliedReportingOverflow(by: 2)
            guard !overflow else { throw PDKProfileOutputError.capacityOverflow }
            let next = max(1, doubled)
            let receipt = try context.reserve(.temporaryBytes, context.bytes(for: Field.self, count: next))
            try context.work(fields.count)
            fields.reserveCapacity(next)
            capacity = next
            fieldReceipt = receipt
        }
        let child = try PDKJSONEncodingNode.make(context: context)
        fields.append(Field(key: key, value: child))
        return child
    }
}
