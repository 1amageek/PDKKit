import PDKCore
import PDKSourceCapture

public protocol PDKBoundedDocumentDecoding: Sendable {
    func decodeManifest(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKManifest>
    func decodeDefinition(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKProfileDefinition>
    func decodeClaim(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKProfileClaim>
}
