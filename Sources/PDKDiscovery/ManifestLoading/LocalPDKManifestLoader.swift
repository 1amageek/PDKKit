import CircuiteFoundation
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import PDKSourceCapture

public struct LocalPDKManifestLoader: PDKManifestLoading {
    private let referencer: any ArtifactReferencing
    private let sourceCapturer: any PDKLocalSourceCapturing

    public init(referencer: any ArtifactReferencing = LocalArtifactReferencer(),
                sourceCapturer: any PDKLocalSourceCapturing = LocalPDKSourceCapturer()) {
        self.referencer = referencer
        self.sourceCapturer = sourceCapturer
    }

    public func discover(at locator: ArtifactLocator, relativeTo root: URL?, captureBudget: ArtifactAccessBudget)
        async throws(PDKManifestLoadingError) -> PDKLoadedManifest {
        try checkInput(locator, root: root)
        let observed: ArtifactReference
        do { observed = try referencer.reference(locator, relativeTo: root) }
        catch is CancellationError { throw .cancelled }
        catch { throw .discovery(reason: String(describing: error)) }
        do { try PDKReference.validateManifest(reference: observed, at: locator) }
        catch { throw .reference(error) }
        let reference: ArtifactReference
        do {
            reference = try ArtifactReference(digest: observed.digest, byteCount: observed.byteCount,
                descriptor: ArtifactDescriptor(role: observed.descriptor.role,
                    kind: ArtifactKind(rawValue: "pdk.technology"), format: .json))
        } catch { throw .invalidInput(reason: String(describing: error)) }
        return try await loadExact(reference: reference, at: locator, relativeTo: root, captureBudget: captureBudget)
    }

    public func loadExact(reference: ArtifactReference, at locator: ArtifactLocator, relativeTo root: URL?, captureBudget: ArtifactAccessBudget)
        async throws(PDKManifestLoadingError) -> PDKLoadedManifest {
        try checkInput(locator, root: root)
        do { try PDKReference.validateManifest(reference: reference, at: locator) }
        catch { throw .reference(error) }
        let captured: CapturedPDKSource
        do { captured = try await sourceCapturer.capture(reference: reference, at: locator, relativeTo: root, budget: captureBudget) }
        catch { throw .source(error) }
        guard captured.reference == reference else { throw .source(.receiptMismatch) }
        guard !Task.isCancelled else { throw .cancelled }
        let loaded = try PDKLoadedManifest(source: captured, locator: locator, maximumCodecByteCount: captureBudget.maximumTotalByteCount)
        guard !Task.isCancelled else { throw .cancelled }
        return loaded
    }

    private func checkInput(_ locator: ArtifactLocator, root: URL?) throws(PDKManifestLoadingError) {
        guard !Task.isCancelled else { throw .cancelled }
        guard locator.format == .json, ["technology", "pdk.technology"].contains(locator.kind.rawValue.lowercased()) else {
            throw .invalidInput(reason: "Manifest availability must describe technology JSON.")
        }
        guard locator.location.storage != .workspaceRelative || root != nil else {
            throw .invalidInput(reason: "A relative manifest requires an explicit root.")
        }
    }
}
