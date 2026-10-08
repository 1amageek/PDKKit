import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import PDKDiscovery
import PDKSourceCapture
import Synchronization
import Testing

@Suite("PDK manifest loading", .timeLimit(.minutes(1)))
struct PDKManifestLoadingTests {
    private struct Fixture {
        let root: URL
        let url: URL
        let locator: ArtifactLocator
        init() throws {
            root = FileManager.default.temporaryDirectory.appending(path: "pdk-load-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            url = root.appending(path: "pdk.json")
            try PDKManifestCodec.encode(PDKManifest(processID: "process-a", version: "1")).write(to: url)
            locator = ArtifactLocator(location: try ArtifactLocation(fileURL: url), role: .input, kind: .technology, format: .json)
        }
        func cleanup() {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record("Fixture cleanup failed: \(error)") }
        }
    }

    private final class Counter: Sendable {
        let value = Mutex(0)
        func increment() { value.withLock { $0 += 1 } }
        var count: Int { value.withLock { $0 } }
    }

    private struct CountingReferencer: ArtifactReferencing {
        let calls: Counter
        let replacement: URL?
        let cancel: Bool
        func reference(_ locator: ArtifactLocator, relativeTo root: URL?) throws -> ArtifactReference {
            calls.increment()
            if cancel { throw CancellationError() }
            let reference = try LocalArtifactReferencer().reference(locator, relativeTo: root)
            if let replacement {
                try PDKManifestCodec.encode(PDKManifest(processID: "process-b", version: "1")).write(to: replacement)
            }
            return reference
        }
    }

    private struct ChangingCapture: PDKLocalSourceCapturing {
        let remove: Bool
        func capture(reference: ArtifactReference, at locator: ArtifactLocator, relativeTo root: URL?, budget: ArtifactAccessBudget)
            async throws(PDKSourceCaptureError) -> CapturedPDKSource {
            let captured = try await LocalPDKSourceCapturer().capture(reference: reference, at: locator, relativeTo: root, budget: budget)
            do {
                let url = try locator.location.resolvedFileURL(relativeTo: root)
                if remove { try FileManager.default.removeItem(at: url) }
                else { try PDKManifestCodec.encode(PDKManifest(processID: "process-b", version: "1")).write(to: url) }
            } catch { throw .invalidLocation(reason: String(describing: error)) }
            return captured
        }
    }

    private struct RefusingCapture: PDKLocalSourceCapturing {
        let error: PDKSourceCaptureError
        func capture(reference: ArtifactReference, at locator: ArtifactLocator, relativeTo root: URL?, budget: ArtifactAccessBudget)
            async throws(PDKSourceCaptureError) -> CapturedPDKSource { throw error }
    }

    private struct SubstitutingCapture: PDKLocalSourceCapturing {
        let substitute: ArtifactReference
        func capture(reference: ArtifactReference, at locator: ArtifactLocator, relativeTo root: URL?, budget: ArtifactAccessBudget)
            async throws(PDKSourceCaptureError) -> CapturedPDKSource {
            let alternate = ArtifactLocator(location: locator.location, role: substitute.descriptor.role,
                                            kind: substitute.kind, format: substitute.format)
            return try await LocalPDKSourceCapturer().capture(reference: substitute, at: alternate, relativeTo: root, budget: budget)
        }
    }

    @Test("an injected capture cannot substitute a producer role")
    func rejectsForeignCaptureIdentity() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let expected = try LocalArtifactReferencer().reference(fixture.locator)
        let substitute = try ArtifactReference(digest: expected.digest, byteCount: expected.byteCount,
            descriptor: ArtifactDescriptor(role: .output, kind: expected.kind, format: expected.format))
        let budget = try PDKSourceCapturePolicy.defaultBudget
        do {
            _ = try await LocalPDKManifestLoader(sourceCapturer: SubstitutingCapture(substitute: substitute)).loadExact(
                reference: expected, at: fixture.locator, relativeTo: fixture.root, captureBudget: budget)
            Issue.record("Substituted identity was published")
        } catch let error as PDKManifestLoadingError {
            guard case .source(.receiptMismatch) = error else { Issue.record("Unexpected failure: \(error)"); return }
        }
    }

    @Test("exact loading preserves a producer output and never discovers identity")
    func exactDoesNotDiscover() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let locator = ArtifactLocator(location: fixture.locator.location, role: .output, kind: .technology, format: .json)
        let expected = try LocalArtifactReferencer().reference(locator)
        let calls = Counter()
        let loader: any PDKManifestLoading = LocalPDKManifestLoader(
            referencer: CountingReferencer(calls: calls, replacement: nil, cancel: false))
        let loaded = try await loader.loadExact(reference: expected, at: locator, relativeTo: fixture.root,
                                              captureBudget: PDKSourceCapturePolicy.defaultBudget)
        #expect(calls.count == 0)
        #expect(loaded.reference.manifest == expected)
        #expect(loaded.manifest.processID == loaded.reference.processID)
        #expect(loaded.reference.manifest.descriptor.role == .output)
    }

    @Test("replacement after identity discovery cannot mix metadata generations")
    func refusesDiscoveryRace() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let calls = Counter()
        let loader = LocalPDKManifestLoader(referencer: CountingReferencer(calls: calls, replacement: fixture.url, cancel: false))
        do {
            _ = try await loader.discover(at: fixture.locator, relativeTo: fixture.root, captureBudget: PDKSourceCapturePolicy.defaultBudget)
            Issue.record("Replacement was accepted")
        } catch let error as PDKManifestLoadingError {
            guard case .source(let source) = error else { Issue.record("Unexpected failure: \(error)"); return }
            #expect(source.classification == .digestMismatch)
        }
        #expect(calls.count == 1)
    }

    @Test("metadata remains bound to captured bytes after replacement or deletion", arguments: [false, true])
    func retainedBytesOwnMetadata(remove: Bool) async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let expected = try LocalArtifactReferencer().reference(fixture.locator)
        let loaded = try await LocalPDKManifestLoader(sourceCapturer: ChangingCapture(remove: remove)).loadExact(
            reference: expected, at: fixture.locator, relativeTo: fixture.root, captureBudget: PDKSourceCapturePolicy.defaultBudget)
        #expect(loaded.reference.manifest == expected)
        #expect(loaded.manifest.processID == "process-a")
        #expect(loaded.reference.processID == "process-a")
    }

    @Test("source cleanup errors and cancellation remain explicit")
    func retainsCleanupFailure() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let expected = try LocalArtifactReferencer().reference(fixture.locator)
        let failure = PDKSourceCaptureError.cleanup(primary: .cancelled, cleanup: .invalidTermination)
        do {
            _ = try await LocalPDKManifestLoader(sourceCapturer: RefusingCapture(error: failure)).loadExact(
                reference: expected, at: fixture.locator, relativeTo: fixture.root, captureBudget: PDKSourceCapturePolicy.defaultBudget)
            Issue.record("Cleanup failure published a manifest")
        } catch let error as PDKManifestLoadingError {
            guard case .source(let actual) = error else { Issue.record("Unexpected failure: \(error)"); return }
            #expect(actual == failure)
            #expect(error.isCancellation)
        }
    }

    @Test("malformed, missing, root-escaping and over-budget sources fail", arguments: ["json", "missing", "root", "budget"])
    func refusesInvalidSources(reason: String) async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        if reason == "json" { try Data("broken".utf8).write(to: fixture.url) }
        if reason == "missing" { try FileManager.default.removeItem(at: fixture.url) }
        let budget = try reason == "budget"
            ? ArtifactAccessBudget(maximumPageByteCount: 1, maximumTotalByteCount: 1, maximumPageCount: 1,
                                   maximumWorkUnitCount: 4, maximumDurationNanoseconds: 1_000_000_000)
            : PDKSourceCapturePolicy.defaultBudget
        let root = reason == "root" ? fixture.root.appending(path: "absent") : fixture.root
        await #expect(throws: PDKManifestLoadingError.self) {
            try await LocalPDKManifestLoader().discover(at: fixture.locator, relativeTo: root, captureBudget: budget)
        }
    }

    @Test("discovery cancellation stops later candidates")
    func stopsDiscoveryAfterCancellation() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try FileManager.default.copyItem(at: fixture.url, to: fixture.root.appending(path: "second.json"))
        let calls = Counter()
        let result = try await LocalPDKDiscoverer(manifestLoader: LocalPDKManifestLoader(
            referencer: CountingReferencer(calls: calls, replacement: nil, cancel: true))).execute(
                PDKDiscoveryRequest(runID: "cancel", inputs: [], searchRoots: [fixture.root.path],
                                    manifestFileNames: ["pdk.json", "second.json"]))
        #expect(result.status == .cancelled)
        #expect(result.payload.candidates.isEmpty)
        #expect(calls.count == 1)
    }
}
