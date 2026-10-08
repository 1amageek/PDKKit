/// In-memory delivery retains the original output owner instead of copying payload bytes.
struct PDKProfileMemoryOutputSink: PDKProfileOutputSink {
    func write(_ bytes: borrowing Span<UInt8>) throws(PDKProfileOutputSinkError) -> Int { bytes.count }
    func finish() throws(PDKProfileOutputSinkError) {}
}
