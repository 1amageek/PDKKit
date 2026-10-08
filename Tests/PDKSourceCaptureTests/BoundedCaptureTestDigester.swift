import CircuiteFoundation
import CircuiteFoundationCrypto
import Synchronization

final class BoundedCaptureTestDigester: ContentDigesting {
    private let calls = Mutex(0)
    var count: Int { calls.withLock { $0 } }
    func digest(using algorithm: ContentDigestAlgorithm, limits: ContentDigestSessionLimits,
                _ body: (borrowing ContentDigestUpdateLease) throws(ContentDigestError) -> Void)
        throws(ContentDigestError) -> ContentDigestResult {
        calls.withLock { $0 += 1 }
        return try SHA256ContentDigester().digest(using: algorithm, limits: limits, body)
    }
}
