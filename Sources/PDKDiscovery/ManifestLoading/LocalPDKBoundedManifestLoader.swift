import CircuiteFoundation
import Foundation
import PDKCore
import PDKSourceCapture

public struct LocalPDKBoundedManifestLoader: PDKBoundedManifestLoading {
    private let capture: any PDKBoundedLocalSourceCapturing
    private let discovery: any PDKLocalSourceDiscovering
    private let decoder: any PDKBoundedDocumentDecoding
    public init(capture: any PDKBoundedLocalSourceCapturing = LocalPDKBoundedSourceCapturer(),
                discovery: any PDKLocalSourceDiscovering = LocalPDKBoundedSourceCapturer(),
                decoder: any PDKBoundedDocumentDecoding = NativePDKBoundedDocumentDecoder()) {
        self.capture = capture; self.discovery = discovery; self.decoder = decoder
    }
    public func discover(descriptor: ArtifactDescriptor, rootURL: URL, rootID: ArtifactRootID,
                         relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                         resources: any PDKAdmissionResourceAccounting)
        async throws(PDKBoundedManifestLoadingError) -> PDKBoundedLoadedManifest {
        let work = PDKManifestLoadingWork(resources: resources)
        try work.json(descriptor)
        let source: CapturedPDKSource
        do { source = try await discovery.discover(descriptor: descriptor, rootURL: rootURL, rootID: rootID,
            relativePath: relativePath, budget: budget, resources: resources) }
        catch { throw .source(error) }
        guard try work.descriptorMatches(source.reference.descriptor, descriptor) else {
            throw .descriptorMismatch(expected: descriptor, actual: source.reference.descriptor)
        }
        return try finish(source, resources: resources)
    }
    public func loadExact(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                          relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                          resources: any PDKAdmissionResourceAccounting)
        async throws(PDKBoundedManifestLoadingError) -> PDKBoundedLoadedManifest {
        let work = PDKManifestLoadingWork(resources: resources)
        try work.json(reference.descriptor)
        let source: CapturedPDKSource
        do { source = try await capture.capture(reference: reference, rootURL: rootURL, rootID: rootID,
            relativePath: relativePath, budget: budget, resources: resources) }
        catch { throw .source(error) }
        guard try work.equal(source.reference, reference) else {
            throw .substitutedSource(expected: reference, actual: source.reference)
        }
        return try finish(source, resources: resources)
    }
    private func finish(_ source: CapturedPDKSource, resources: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedManifestLoadingError) -> PDKBoundedLoadedManifest {
        let work = PDKManifestLoadingWork(resources: resources)
        try work.check()
        let document: PDKDecodedDocument<PDKManifest>
        do { document = try decoder.decodeManifest(source, accounting: resources) }
        catch { throw .decode(error) }
        return try PDKBoundedLoadedManifest(source: source, document: document, resources: resources)
    }
}
