import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import PDKDiscovery
import PDKKitCLICore
import PDKSourceCapture
import PDKStandardViews
import PDKValidation
import Synchronization
import Testing

@Suite("PDK manifest entrypoints", .timeLimit(.minutes(1)))
struct PDKManifestEntryTests {
    private final class Counter: Sendable {
        let value = Mutex(0)
        var count: Int { value.withLock { $0 } }
        func increment() { value.withLock { $0 += 1 } }
    }
    private struct CancellingLoader: PDKManifestLoading {
        let calls: Counter
        func discover(at locator: ArtifactLocator, relativeTo root: URL?, captureBudget: ArtifactAccessBudget)
            async throws(PDKManifestLoadingError) -> PDKLoadedManifest {
            calls.increment()
            throw .cancelled
        }
        func loadExact(reference: ArtifactReference, at locator: ArtifactLocator, relativeTo root: URL?, captureBudget: ArtifactAccessBudget)
            async throws(PDKManifestLoadingError) -> PDKLoadedManifest {
            calls.increment()
            throw .cancelled
        }
    }

    @Test("corpus cancellation stops subsequent cases")
    func corpusStopsAfterCancellation() async throws {
        let fixture = try await BoundCaptureFixture()
        defer { fixture.cleanup() }
        let suite = PDKCorpusSuite(suiteID: "cancel", processID: fixture.pdk.processID, version: fixture.pdk.version,
            cases: [PDKCorpusCase(caseID: "a", manifestPath: "pdk.json", expectedOutcome: .valid),
                    PDKCorpusCase(caseID: "b", manifestPath: "pdk.json", expectedOutcome: .valid)])
        let url = fixture.root.appending(path: "suite.json")
        try PDKCorpusSuiteCodec().encode(suite).write(to: url)
        let calls = Counter()
        let result = try await LocalPDKCorpusValidator(manifestLoader: CancellingLoader(calls: calls)).execute(
            PDKCorpusValidationRequest(runID: "cancel", suitePath: url.path, rootPath: fixture.root.path))
        #expect(result.status == .cancelled)
        #expect(!result.payload.isValid)
        #expect(result.payload.caseResults.isEmpty)
        #expect(calls.count == 1)
    }

    @Test("obsolete native request versions are rejected before file acquisition")
    func rejectsOldRequestVersions() async throws {
        let fixture = try await BoundCaptureFixture()
        defer { fixture.cleanup() }
        var view = fixture.viewRequest()
        var rule = fixture.ruleRequest()
        var oracle = try fixture.oracleRequest()
        var validation = PDKValidationRequest(runID: "old", inputs: [], pdk: fixture.pdk)
        var discovery = PDKDiscoveryRequest(runID: "old", inputs: [], searchRoots: [fixture.root.path])
        view.schemaVersion -= 1
        rule.schemaVersion -= 1
        oracle.schemaVersion -= 1
        validation.schemaVersion -= 1
        discovery.schemaVersion -= 1
        try FileManager.default.removeItem(at: fixture.root.appending(path: "pdk.json"))
        let viewed = try await LocalPDKManifestViewInspector().execute(view)
        let ruled = try await LocalPDKRuleDeckInspector().execute(rule)
        let compared = try await LocalPDKOracleComparator().execute(oracle)
        let validated = try await LocalPDKValidator().execute(validation)
        let discovered = try await LocalPDKDiscoverer().execute(discovery)
        for (status, diagnostics) in [(viewed.status, viewed.diagnostics), (ruled.status, ruled.diagnostics),
                                     (compared.status, compared.diagnostics), (validated.status, validated.diagnostics),
                                     (discovered.status, discovered.diagnostics)] {
            #expect(status == .blocked)
            #expect(diagnostics.contains { $0.code.rawValue.hasSuffix("request-schema-unsupported") })
        }
    }

    @Test("CLI inspect publishes matching manifest metadata and identity")
    func inspectPublishesOneGeneration() async throws {
        let fixture = try await BoundCaptureFixture()
        defer { fixture.cleanup() }
        let url = fixture.root.appending(path: "pdk.json")
        let result = await PDKKitCLI.invoke(arguments: ["inspect", "--manifest", url.path])
        #expect(result.exitCode == 0, "\(result.standardError)")
        let object = try #require(JSONSerialization.jsonObject(with: Data(result.standardOutput.utf8)) as? [String: Any])
        let manifest = try #require(object["manifest"] as? [String: Any])
        #expect(manifest["processID"] as? String == fixture.pdk.processID)
        let digest = try SHA256ContentDigester().digest(data: Data(contentsOf: url)).hexadecimalValue
        #expect(object["digest"] as? String == digest)
        let invalid = await PDKKitCLI.invoke(arguments: ["inspect", "--manifest", fixture.root.appending(path: "missing.json").path])
        #expect(invalid.exitCode == 1)
        #expect(invalid.standardError.contains("pdkkit.cli.unreadable-file"))
    }
}
