import CircuiteFoundationFoundation
import PDKCore
import PDKSourceCapture

public struct PDKLoadedManifest: Sendable {
    public let manifest: PDKManifest
    public let reference: PDKReference

    // Only admitted bytes can create a metadata/identity pair. Decoding a claim
    // cannot recreate this evidence-bearing value.
    internal init(source: CapturedPDKSource, locator: ArtifactLocator, maximumCodecByteCount: UInt64)
        throws(PDKManifestLoadingError) {
        let decoded: PDKManifest
        do {
            decoded = try PDKManifestCodec.decode(data: source.data(maximumByteCount: maximumCodecByteCount))
        } catch let error as PDKSourceCaptureError { throw .source(error) }
        catch let error as PDKManifestError { throw .manifest(error) }
        catch { throw .manifest(.invalidField(field: "json", reason: String(describing: error))) }
        let claim: PDKReference
        do {
            claim = try PDKReference(manifest: source.reference, manifestLocator: locator,
                                     processID: decoded.processID, version: decoded.version)
        } catch { throw .reference(error) }
        self.manifest = decoded
        self.reference = claim
    }
}
