/// Implementations report actual bytes written and complete their own flush/close boundary.
public protocol PDKProfileOutputSink: Sendable {
    func write(_ bytes: borrowing Span<UInt8>) throws(PDKProfileOutputSinkError) -> Int
    func finish() throws(PDKProfileOutputSinkError)
}
