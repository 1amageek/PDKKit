import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import PDKDiscovery
import PDKSourceCapture
import Testing

@Suite(.timeLimit(.minutes(1)))
struct BoundedManifestLoadingTests {
    private struct Fixture {
        let root: URL
        let rootID: ArtifactRootID
        let path: ArtifactRelativePath
        let descriptor: ArtifactDescriptor
        let bytes: Data
        let budget: ArtifactAccessBudget
        init() throws {
            root = FileManager.default.temporaryDirectory.appending(path: "pdk-bounded-load-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            rootID = try ArtifactRootID(rawValue: UUID().uuidString)
            path = try ArtifactRelativePath(segments: ["pdk.json"])
            descriptor = try ArtifactDescriptor(role: .output, kind: ArtifactKind(rawValue: "pdk.technology"), format: .json)
            bytes = try PDKManifestCodec.encode(PDKManifest(processID: "p", version: "1"))
            budget = try PDKSourceCapturePolicy.defaultBudget
            try bytes.write(to: root.appending(path: "pdk.json"))
        }
        func cleanup() {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record("Fixture cleanup failed: \(error)") }
        }
        func discover(_ resources: ManifestLoadTestAccounting) async throws -> PDKBoundedLoadedManifest {
            try await LocalPDKBoundedManifestLoader().discover(descriptor: descriptor, rootURL: root,
                rootID: rootID, relativePath: path, budget: budget, resources: resources)
        }
        func exact(_ reference: ArtifactReference, _ resources: ManifestLoadTestAccounting,
                   decoder: any PDKBoundedDocumentDecoding = NativePDKBoundedDocumentDecoder())
            async throws -> PDKBoundedLoadedManifest {
            try await LocalPDKBoundedManifestLoader(decoder: decoder).loadExact(reference: reference,
                rootURL: root, rootID: rootID, relativePath: path, budget: budget, resources: resources)
        }
    }
    private struct AlternateDecoder: PDKBoundedDocumentDecoding {
        let alternate: CapturedPDKSource?
        let cancel: ManifestLoadTestAccounting?
        var cancelAfterDecode = false
        func decodeManifest(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
            throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKManifest> {
            if let cancel, !cancelAfterDecode { cancel.failure = .cancelled }
            let result = try NativePDKBoundedDocumentDecoder().decodeManifest(alternate ?? source, accounting: accounting)
            if let cancel, cancelAfterDecode { cancel.failure = .cancelled }
            return result
        }
        func decodeDefinition(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
            throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKProfileDefinition> {
            try NativePDKBoundedDocumentDecoder().decodeDefinition(source, accounting: accounting)
        }
        func decodeClaim(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
            throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKProfileClaim> {
            try NativePDKBoundedDocumentDecoder().decodeClaim(source, accounting: accounting)
        }
    }
    private struct SubstitutingDiscovery: PDKLocalSourceDiscovering {
        func discover(descriptor: ArtifactDescriptor, rootURL: URL, rootID: ArtifactRootID,
                      relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                      resources: any PDKAdmissionResourceAccounting)
            async throws(PDKSourceCaptureError) -> CapturedPDKSource {
            let different: ArtifactDescriptor
            do { different = try ArtifactDescriptor(role: .input, kind: descriptor.kind, format: descriptor.format) }
            catch { throw .invalidLocation(reason: "Fixture descriptor construction failed") }
            return try await LocalPDKBoundedSourceCapturer().discover(descriptor: different,
                rootURL: rootURL, rootID: rootID, relativePath: relativePath, budget: budget, resources: resources)
        }
    }
    @Test func discoveredSourceCannotReplaceTheRequestedDescriptor() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        do {
            _ = try await LocalPDKBoundedManifestLoader(discovery: SubstitutingDiscovery()).discover(
                descriptor: fixture.descriptor, rootURL: fixture.root, rootID: fixture.rootID,
                relativePath: fixture.path, budget: fixture.budget, resources: resources)
            Issue.record("A discovered source changed the requested descriptor")
        } catch let error as PDKBoundedManifestLoadingError {
            guard case .descriptorMismatch(let expected, let actual) = error else { Issue.record("Unexpected failure: \(error)"); return }
            #expect(expected == fixture.descriptor)
            #expect(actual.role == .input)
        }
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.openResources) == 0)
    }
    @Test func sameReadDiscoveryAndExactPreserveProducerRoleAfterDeletion() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        let discovered = try await fixture.discover(resources)
        let exact = try await fixture.exact(discovered.reference, resources)
        try FileManager.default.removeItem(at: fixture.root.appending(path: "pdk.json"))
        #expect(discovered.manifest.processID == "p")
        #expect(exact.manifest == discovered.manifest)
        #expect(exact.reference == discovered.reference)
        #expect(exact.reference.descriptor.role == .output)
        #expect(resources.used(.readBytes) == UInt64(fixture.bytes.count * 2))
        #expect(resources.used(.hashedBytes) == UInt64(fixture.bytes.count * 4))
        #expect(resources.used(.openResources) == 0)
    }
    @Test func exactTamperIsRejectedWithoutReplacementDiscovery() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        let original = try await fixture.discover(resources)
        let retained = resources.used(.liveOwnedBytes)
        let replaced = try PDKManifestCodec.encode(PDKManifest(processID: "q", version: "1"))
        #expect(replaced.count == fixture.bytes.count)
        try replaced.write(to: fixture.root.appending(path: "pdk.json"))
        do {
            _ = try await fixture.exact(original.reference, resources)
            Issue.record("Tampered manifest was published")
        } catch let error as PDKBoundedManifestLoadingError {
            guard case .source(.digestMismatch) = error else { Issue.record("Unexpected failure: \(error)"); return }
        }
        #expect(resources.used(.readBytes) == UInt64(fixture.bytes.count * 2))
        #expect(resources.used(.liveOwnedBytes) == retained)
        #expect(resources.used(.openResources) == 0)
        #expect(original.manifest.processID == "p")
    }
    @Test func aDecoderCannotSubstituteAnEqualDigestWithDifferentDescriptor() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        let original = try await fixture.discover(resources)
        let alternate = try await LocalPDKBoundedSourceCapturer().discover(
            descriptor: ArtifactDescriptor(role: .input, kind: fixture.descriptor.kind, format: .json),
            rootURL: fixture.root, rootID: fixture.rootID, relativePath: fixture.path,
            budget: fixture.budget, resources: resources)
        #expect(original.reference.id == alternate.reference.id)
        do {
            _ = try await fixture.exact(original.reference, resources,
                decoder: AlternateDecoder(alternate: alternate, cancel: nil))
            Issue.record("A decoder's foreign input binding was published")
        } catch let error as PDKBoundedManifestLoadingError {
            guard case .decodedSourceMismatch(let expected, let actual) = error else { Issue.record("Unexpected failure: \(error)"); return }
            #expect(expected == original.reference)
            #expect(actual == alternate.reference)
        }
        #expect(resources.used(.openResources) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
    }
    @Test func copiedLoadedOwnerRetainsBothSourceAndDecodedCapacity() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        var loaded: PDKBoundedLoadedManifest? = try await fixture.discover(resources)
        var copy = loaded
        let held = resources.used(.liveOwnedBytes)
        #expect(held > UInt64(fixture.bytes.count))
        loaded = nil
        #expect(copy?.manifest.processID == "p")
        #expect(resources.used(.liveOwnedBytes) == held)
        copy = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
    }
    @Test func cumulativeDecodeLimitRejectsSecondManifestAndUnwindsOnlyItsOwner() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let probe = ManifestLoadTestAccounting()
        var measured: PDKBoundedLoadedManifest? = try await fixture.discover(probe)
        #expect(measured?.manifest.processID == "p")
        let elements = probe.used(.decodedElements)
        measured = nil
        let resources = ManifestLoadTestAccounting(); resources.limit(.decodedElements, to: elements * 2 - 1)
        var first: PDKBoundedLoadedManifest? = try await fixture.discover(resources)
        let retained = resources.used(.liveOwnedBytes)
        do {
            _ = try await fixture.discover(resources)
            Issue.record("Cumulative decode quota was reset")
        } catch let error as PDKBoundedManifestLoadingError {
            guard case .decode(.resource(.exhausted(let dimension, _, _))) = error else { Issue.record("Unexpected failure: \(error)"); return }
            #expect(dimension == .decodedElements)
        }
        #expect(first?.manifest.processID == "p")
        #expect(resources.used(.liveOwnedBytes) == retained)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.openResources) == 0)
        first = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
    }
    @Test(arguments: [false, true]) func typedDecodeCancellationPublishesNothingAndReleasesCapturedOwner(afterDecode: Bool) async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        let reference = try await fixture.discover(ManifestLoadTestAccounting()).reference
        do {
            _ = try await fixture.exact(reference, resources, decoder: AlternateDecoder(alternate: nil, cancel: resources, cancelAfterDecode: afterDecode))
            Issue.record("Cancelled manifest loading was published")
        } catch let error as PDKBoundedManifestLoadingError {
            #expect(error.isCancellation)
            #expect(error == (afterDecode ? .resource(.cancelled) : .decode(.resource(.cancelled))))
        }
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.openResources) == 0)
        #expect(resources.used(.concurrentAcquisitions) == 0)
    }
}
