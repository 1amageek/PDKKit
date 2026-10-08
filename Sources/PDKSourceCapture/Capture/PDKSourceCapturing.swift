import CircuiteFoundation

public protocol PDKSourceCapturing: Sendable {
    func capture(
        _ intent: ArtifactAccessIntent
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource
}
