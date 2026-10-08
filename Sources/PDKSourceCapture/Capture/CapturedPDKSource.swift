import CircuiteFoundation
import Foundation

public struct CapturedPDKSource: Sendable {
    public let reference: ArtifactReference
    private let storage: [UInt8]

    public var byteCount: UInt64 { UInt64(storage.count) }

    // Construction is restricted to checked capture. The digest uses this exact
    // immutable owned buffer; a backend receipt cannot substitute for its bytes.
    internal init(
        reference: ArtifactReference,
        bytes: consuming [UInt8],
        digester: any ContentDigesting
    ) throws(PDKSourceCaptureError) {
        guard UInt64(bytes.count) == reference.byteCount else {
            throw .byteCountMismatch(expected: reference.byteCount, actual: UInt64(bytes.count))
        }
        let result: ContentDigestResult
        do {
            let limits = try ContentDigestSessionLimits(
                maximumChunkByteCount: max(UInt64(bytes.count), 1),
                maximumTotalByteCount: max(UInt64(bytes.count), 1),
                maximumUpdateCount: 1
            )
            result = try digester.digest(using: reference.digest.algorithm, limits: limits) {
                (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in
                try lease.update(bytes)
            }
        } catch { throw .digest(error) }
        guard result.totalByteCount == reference.byteCount, result.updateCount == 1 else {
            throw .receiptMismatch
        }
        guard result.digest == reference.digest else {
            throw .digestMismatch(expected: reference.digest, actual: result.digest)
        }
        self.reference = reference
        self.storage = bytes
    }

    public func withBytes<Result>(
        _ body: (borrowing Span<UInt8>) throws -> Result
    ) rethrows -> Result {
        try body(storage.span)
    }

    /// Codec-boundary copy. Callers must include this additional owned buffer
    /// alongside the capture and parser allocations in their memory budget.
    public func data(maximumByteCount: UInt64) throws(PDKSourceCaptureError) -> Data {
        guard byteCount <= maximumByteCount else {
            throw .byteLimitExceeded(limit: maximumByteCount, actual: byteCount)
        }
        return Data(storage)
    }
}
