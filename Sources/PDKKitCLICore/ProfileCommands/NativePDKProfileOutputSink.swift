#if canImport(Darwin)
import Darwin
#endif

/// A scoped span write to a caller-owned descriptor; no intermediate Data or String.
public struct NativePDKProfileOutputSink: PDKProfileOutputSink {
    private let descriptor: Int32
    public init(descriptor: Int32) { self.descriptor = descriptor }
    public func write(_ bytes: borrowing Span<UInt8>) throws(PDKProfileOutputSinkError) -> Int {
        #if canImport(Darwin)
        // A per-descriptor policy keeps EPIPE typed without changing process-wide signal handling.
        guard fcntl(descriptor, F_SETNOSIGPIPE, 1) == 0 else { throw .writeFailed }
        let count = bytes.withUnsafeBufferPointer { buffer in
            Darwin.write(descriptor, buffer.baseAddress, buffer.count)
        }
        guard count >= 0 else { throw .writeFailed }
        return count
        #else
        // FIXME(INCOMPLETE_IMPLEMENTATION): No verified non-Darwin SIGPIPE-safe
        // descriptor writer is implemented. Native profile CLI delivery on these
        // platforms refuses success until typed closed-pipe behavior is proven.
        throw .writeFailed
        #endif
    }
    public func finish() throws(PDKProfileOutputSinkError) {
        // write(2) transfers every reported byte to the descriptor; the CLI does not own its close.
    }
}
