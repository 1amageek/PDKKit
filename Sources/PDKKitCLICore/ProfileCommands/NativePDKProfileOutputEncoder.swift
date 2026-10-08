import PDKCore

public struct NativePDKProfileOutputEncoder: PDKProfileOutputEncoding {
    public init() {}
    public func reserveCompletion(resources: any PDKAdmissionResourceAccounting,
                                  policy: PDKProfileOutputCompletionPolicy = .standard)
        throws(PDKProfileOutputError) -> PDKProfileOutputCompletion {
        do {
            let terminal = "{\"schemaVersion\":1,\"status\":\"failed\",\"reason\":\"output_failure\"}\n"
            let size = UInt64(terminal.utf8.count)
            let entry = try resources.reserve(PDKAdmissionCost(dimension: .diagnosticEntries, amount: 1))
            let diagnostic = try resources.reserve(PDKAdmissionCost(dimension: .diagnosticBytes, amount: size))
            let storage = try resources.reserve(PDKAdmissionCost(dimension: .liveOwnedBytes, amount: size))
            let scratch = try resources.reserve(PDKAdmissionCost(dimension: .temporaryBytes, amount: 32))
            let (work, overflow) = policy.maximumSuffixByteCount.multipliedReportingOverflow(by: 2)
            guard !overflow else { throw PDKProfileOutputError.capacityOverflow }
            let (total, additionOverflow) = work.addingReportingOverflow(32 * (3 * PDKAdmissionResourceDimension.allCases.count + 6) + terminal.utf8.count)
            guard !additionOverflow else { throw PDKProfileOutputError.capacityOverflow }
            _ = try resources.reserve(PDKAdmissionCost(dimension: .parserWork, amount: UInt64(total)))
            let output = PDKOwnedProfileOutput(bytes: Array(terminal.utf8), resources: resources,
                                              reservations: [entry, diagnostic, storage])
            return PDKProfileOutputCompletion(owner: .init(resources: resources, policy: policy,
                                                          terminal: output, scratch: scratch))
        } catch { throw .preserving(error) }
    }

    public func prepare<Value: Encodable>(_ envelope: Value, completion: PDKProfileOutputCompletion)
        throws(PDKProfileOutputError) -> PDKPreparedProfileOutput {
        try completion.owner.take()
        do {
            let context = PDKJSONEncodingContext(resources: completion.owner.resources)
            let node = try PDKJSONEncodingNode.make(context: context)
            try envelope.encode(to: PDKCooperativeJSONEncoder(context: context, node: node))
            try context.check()
            guard node.kind == .keyed else { throw PDKProfileOutputError.invalidEncoding }
            for field in node.fields {
                try context.work((field.key?.utf8.count ?? 0) + "operationalObservations".utf8.count + 1)
                guard field.key != "operationalObservations" else { throw PDKProfileOutputError.invalidEncoding }
            }
            var writer = PDKJSONByteWriter(context: context)
            try writer.write(node)
            let (capacity, overflow) = (writer.bytes.count - 1).addingReportingOverflow(completion.owner.policy.maximumSuffixByteCount)
            guard !overflow else { throw PDKProfileOutputError.capacityOverflow }
            guard let destination = try context.reserve(.liveOwnedBytes, capacity) else {
                throw PDKProfileOutputError.capacityOverflow
            }
            try context.work(writer.bytes.count - 1)
            try context.check()
            let payload = PDKOwnedProfileOutput(bytes: writer.bytes, resources: completion.owner.resources,
                                               reservations: writer.receipt.map { [$0] } ?? [])
            return PDKPreparedProfileOutput(payload: payload, completion: completion, destination: destination,
                                            capacity: capacity, hasPayloadFields: !node.fields.isEmpty)
        } catch { throw .preserving(error) }
    }
}
