import CircuiteFoundation
import Foundation

struct CaptureTestBytes: ArtifactOwnedBytes {
    let storage: [UInt8]
    let byteCount: UInt64

    func withUnsafeBytes<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
        try storage.withUnsafeBytes(body)
    }
}
