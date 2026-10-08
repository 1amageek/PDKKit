import PDKCore
import PDKSourceCapture

/// A discovered source declaration and its verified owned bytes.
public struct PDKSpiceCandidateSource: Sendable {
    public let source: PDKProfileSource
    public let capture: CapturedPDKSource
    internal init(source: PDKProfileSource, capture: CapturedPDKSource) { self.source = source; self.capture = capture }
}
