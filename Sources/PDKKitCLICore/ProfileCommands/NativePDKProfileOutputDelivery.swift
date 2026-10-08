public struct NativePDKProfileOutputDelivery: PDKProfileOutputDelivering {
    public init() {}
    public func deliver(_ output: PDKOwnedProfileOutput, to sink: any PDKProfileOutputSink)
        throws(PDKProfileOutputError) -> PDKDeliveredProfileOutput {
        do {
            try output.resources.check()
            let count = try output.withBytes { try sink.write($0) }
            guard count == output.byteCount else {
                throw PDKProfileOutputError.shortWrite(expected: output.byteCount, actual: count)
            }
            try sink.finish()
            try output.resources.check()
            return PDKDeliveredProfileOutput(output: output)
        } catch let error as PDKProfileOutputSinkError { throw .sink(error) }
        catch { throw .preserving(error) }
    }
}
