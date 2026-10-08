import PDKCore
import PDKDiscovery
import PDKSourceCapture
import TechIR

/// An audited IRTechLibrary specialization, including strict data-only validation.
public protocol PDKStandardTechnologyDecoding: Sendable {
    func decodeTechnology(_ source: CapturedPDKSource, resources: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<IRTechLibrary>
}
