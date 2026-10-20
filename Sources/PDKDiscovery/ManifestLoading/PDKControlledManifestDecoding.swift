import PDKCore

/// Caller-neutral manifest loading under the invocation's existing accountant.
public protocol PDKControlledManifestDecoding: Sendable {
    func decodeAndValidateManifest(bytes: borrowing Span<UInt8>,
        accounting: any PDKAdmissionResourceAccounting) throws(PDKControlledDecodeFailure) -> PDKControlledManifest
}
