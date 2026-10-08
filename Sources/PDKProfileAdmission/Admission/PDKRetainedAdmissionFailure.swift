import PDKCore
import PDKDiscovery
import PDKSourceCapture

/// Keep this owner while inspecting input-derived failure payloads.
public final class PDKRetainedAdmissionFailure: Sendable, Equatable {
    public let underlyingReason: PDKProfileAdmissionError
    private let document: PDKDecodedDocument<PDKProfileDefinition>
    private let definitionSource: CapturedPDKSource
    internal init(reason: PDKProfileAdmissionError, document: PDKDecodedDocument<PDKProfileDefinition>, source: CapturedPDKSource) {
        underlyingReason = reason; self.document = document; definitionSource = source
    }
    public static func == (lhs: PDKRetainedAdmissionFailure, rhs: PDKRetainedAdmissionFailure) -> Bool {
        lhs.underlyingReason == rhs.underlyingReason
    }
}
