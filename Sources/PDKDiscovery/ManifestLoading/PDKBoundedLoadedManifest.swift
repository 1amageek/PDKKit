import CircuiteFoundation
import PDKCore
import PDKSourceCapture

/// Retain this handle for the source and decoded value's invocation-managed lifetime.
public struct PDKBoundedLoadedManifest: Sendable {
    public let source: CapturedPDKSource
    private let document: PDKDecodedDocument<PDKManifest>
    public var manifest: PDKManifest { document.value }
    public var reference: ArtifactReference { source.reference }

    internal init(source: CapturedPDKSource, document: PDKDecodedDocument<PDKManifest>,
                  resources: any PDKAdmissionResourceAccounting) throws(PDKBoundedManifestLoadingError) {
        let work = PDKManifestLoadingWork(resources: resources)
        try work.check()
        guard let decodedReference = document.sourceReference else {
            throw .decodedSourceMismatch(expected: source.reference, actual: nil)
        }
        guard try work.equal(source.reference, decodedReference) else {
            throw .decodedSourceMismatch(expected: source.reference, actual: decodedReference)
        }
        self.source = source; self.document = document
        try work.check()
    }
}
