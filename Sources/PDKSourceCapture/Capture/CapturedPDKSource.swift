import CircuiteFoundation
import Foundation
import PDKCore

public struct CapturedPDKSource: Sendable {
    public let reference: ArtifactReference
    private let storage: [UInt8]
    private let reservation: PDKAdmissionReservation?
    private let isInvocationAccounted: Bool

    public var byteCount: UInt64 { UInt64(storage.count) }

    // Construction is restricted to checked capture. The digest uses this exact
    // immutable owned buffer; a backend receipt cannot substitute for its bytes.
    internal init(
        reference: ArtifactReference,
        bytes: consuming [UInt8],
        digester: any ContentDigesting,
        resources: (any PDKAdmissionResourceAccounting)? = nil,
        reservation: PDKAdmissionReservation? = nil
    ) throws(PDKSourceCaptureError) {
        guard UInt64(bytes.count) == reference.byteCount else {
            throw .byteCountMismatch(expected: reference.byteCount, actual: UInt64(bytes.count))
        }
        if resources != nil, !bytes.isEmpty {
            guard let reservation, reservation.cost.dimension == .liveOwnedBytes,
                  reservation.cost.amount >= UInt64(bytes.count) else {
                throw .resource(.unsupportedBudgetCapability("Bounded capture requires its admitted storage owner"))
            }
        }
        let result: ContentDigestResult
        if let resources {
            result = try Self.checkedDigest(bytes, reference: reference, digester: digester, resources: resources)
        } else {
            do {
                let limits = try ContentDigestSessionLimits(
                    maximumChunkByteCount: max(UInt64(bytes.count), 1),
                    maximumTotalByteCount: max(UInt64(bytes.count), 1), maximumUpdateCount: 1)
                result = try digester.digest(using: reference.digest.algorithm, limits: limits) {
                    (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in
                    try lease.update(bytes)
                }
            } catch { throw .digest(error) }
            guard result.totalByteCount == reference.byteCount, result.updateCount == 1 else { throw .receiptMismatch }
        }
        guard result.digest == reference.digest else {
            throw .digestMismatch(expected: reference.digest, actual: result.digest)
        }
        self.reference = reference
        self.storage = bytes
        self.reservation = reservation
        self.isInvocationAccounted = resources != nil
    }

    private static func checkedDigest(_ bytes: [UInt8], reference: ArtifactReference,
        digester: any ContentDigesting, resources: any PDKAdmissionResourceAccounting)
        throws(PDKSourceCaptureError) -> ContentDigestResult {
        let work = PDKSourceConstructionWork(resources: resources)
        try work.check()
        let capacity = min(bytes.count, 4096)
        let chunkReservation = try work.reserve(.temporaryBytes, UInt64(capacity))
        defer { withExtendedLifetime(chunkReservation) {} }
        let updates = bytes.count / 4096 + (bytes.count % 4096 == 0 ? 0 : 1)
        var primary: PDKSourceCaptureError?
        let result: ContentDigestResult
        do throws(ContentDigestError) {
            let limits = try ContentDigestSessionLimits(maximumChunkByteCount: UInt64(max(capacity, 1)),
                maximumTotalByteCount: UInt64(max(bytes.count, 1)), maximumUpdateCount: UInt64(max(updates, 1)))
            result = try digester.digest(using: reference.digest.algorithm, limits: limits) {
                (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in
                var chunk: [UInt8] = []; chunk.reserveCapacity(capacity)
                var offset = 0
                while offset < bytes.count {
                    let end = offset + min(capacity, bytes.count - offset)
                    do throws(PDKSourceCaptureError) {
                        try work.charge(.hashedBytes, UInt64(end - offset))
                        try work.charge(.parserWork, UInt64(end - offset))
                    } catch { primary = error; throw .backendUpdateFailed(reason: "PDK source resource admission failed") }
                    chunk.removeAll(keepingCapacity: true)
                    chunk.append(contentsOf: bytes[offset..<end])
                    try lease.update(chunk)
                    do throws(PDKSourceCaptureError) { try work.check() }
                    catch { primary = error; throw .backendUpdateFailed(reason: "PDK source resource admission failed") }
                    offset = end
                }
            }
        } catch {
            if let primary {
                if case .abortFailed(_, let abort) = error { throw .cleanup(primary: primary, cleanup: .digest(abort)) }
                throw primary
            }
            throw .digest(error)
        }
        try work.check()
        guard result.totalByteCount == reference.byteCount, result.updateCount == UInt64(updates) else { throw .receiptMismatch }
        return result
    }

    public func withBytes<Result>(
        _ body: (borrowing Span<UInt8>) throws -> Result
    ) rethrows -> Result {
        try body(storage.span)
    }

    /// Shares checked content and its retained owner under a new full descriptor.
    public func rebinding(reference: ArtifactReference,
                          resources: any PDKAdmissionResourceAccounting)
        throws(PDKSourceCaptureError) -> CapturedPDKSource {
        let work = PDKSourceConstructionWork(resources: resources)
        try work.check()
        guard isInvocationAccounted else {
            throw .resource(.unsupportedBudgetCapability("Profile aliasing requires invocation-accounted source storage"))
        }
        guard reference.byteCount == self.reference.byteCount else {
            throw .byteCountMismatch(expected: reference.byteCount, actual: self.reference.byteCount)
        }
        guard reference.digest.algorithm == self.reference.digest.algorithm,
              try work.equal(reference.digest.hexadecimalValue, self.reference.digest.hexadecimalValue) else {
            throw .digestMismatch(expected: reference.digest, actual: self.reference.digest)
        }
        let alias = CapturedPDKSource(reference: reference, source: self)
        try work.check()
        return alias
    }

    private init(reference: ArtifactReference, source: CapturedPDKSource) {
        self.reference = reference
        self.storage = source.storage
        self.reservation = source.reservation
        self.isInvocationAccounted = source.isInvocationAccounted
    }

    /// Codec-boundary copy. Callers must include this additional owned buffer
    /// alongside the capture and parser allocations in their memory budget.
    public func data(maximumByteCount: UInt64) throws(PDKSourceCaptureError) -> Data {
        guard !isInvocationAccounted else {
            throw .resource(.unsupportedBudgetCapability("Bounded capture export requires a caller-owned admitted copy"))
        }
        guard byteCount <= maximumByteCount else {
            throw .byteLimitExceeded(limit: maximumByteCount, actual: byteCount)
        }
        return Data(storage)
    }
}
