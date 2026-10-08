import CircuiteFoundation
import Foundation
import PDKCore
import PDKSourceCapture
import PDKStandardViews
import Testing

struct PDKBoundSourceCaptureTests {
    @Test("Manifest-bound views parse the captured manifest after path mutation", arguments: [false, true])
    func manifestViewUsesCapturedBytes(remove: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let result = try await LocalPDKManifestViewInspector(
            sourceCapturer: BoundMutatingSourceCapturer(fileName: "pdk.json", mutation: remove ? .remove : .replace)
        ).execute(fixture.viewRequest())
        #expect(result.status == .completed, "\(result.diagnostics)")
        #expect(result.payload.binding?.isValid == true)
        #expect(result.payload.inspection?.inspection?.cellNames == ["nmos"])
    }

    @Test("Rules parse captured manifest and text after mutation", arguments: ["pdk.json", "rules.deck"], [false, true])
    func ruleUsesCapturedBytes(fileName: String, remove: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let result = try await LocalPDKRuleDeckInspector(
            sourceCapturer: BoundMutatingSourceCapturer(fileName: fileName, mutation: remove ? .remove : .replace)
        ).execute(fixture.ruleRequest())
        #expect(result.status == .completed, "\(result.diagnostics)")
        #expect(result.payload.isValid)
        #expect(result.payload.observedLayerIDs == ["active", "metal1"])
        #expect(result.payload.statementCount > 0)
    }

    @Test("External rule identity derives from captured manifest", arguments: [false, true])
    func externalRuleUsesCapturedManifest(remove: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let request = fixture.ruleRequest()
        let local = try await LocalPDKRuleDeckInspector().execute(request)
        let result = try await ExternalPDKRuleDeckInspector(
            provider: BoundRuleResultProvider(data: try JSONEncoder().encode(local)),
            sourceCapturer: BoundMutatingSourceCapturer(fileName: "pdk.json", mutation: remove ? .remove : .replace)
        ).execute(request)
        #expect(result.status == .completed, "\(result.diagnostics)")
        #expect(result.payload.sourceArtifact == local.payload.sourceArtifact)
    }

    @Test("Oracle compares captured expectations after path mutation", arguments: [false, true])
    func oracleUsesCapturedBytes(remove: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let request = try fixture.oracleRequest()
        let result = try await LocalPDKOracleComparator(
            sourceCapturer: BoundMutatingSourceCapturer(fileName: "oracle.json", mutation: remove ? .remove : .replace)
        ).execute(request)
        #expect(result.status == .completed, "\(result.diagnostics)")
        #expect(result.payload.oracleID == "captured-oracle")
        #expect(result.payload.oracleArtifact == request.oracle)
        #expect(result.payload.comparisons.first?.isMatch == true)
    }

    @Test("Manifest binding refuses missing or substituted full source identity", arguments: [false, true])
    func substitutedIdentityIsRefused(removeIdentity: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let result = try await LocalPDKManifestViewInspector(
            standardInspector: BoundSubstitutingStandardInspector(removeIdentity: removeIdentity)
        ).execute(fixture.viewRequest())
        #expect(result.status == .blocked)
        #expect(!result.payload.isValid)
        #expect(result.payload.binding == nil)
        #expect(result.payload.findings.contains { $0.code == "pdk.standard-view.source-artifact-mismatch" })
    }

    @Test("Capture cancellation and cleanup cannot yield view, rule, external or oracle success", arguments: [false, true])
    func captureFailureIsRefused(cleanup: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let error: PDKSourceCaptureError = cleanup
            ? .cleanup(primary: .cancelled, cleanup: .invalidTermination) : .cancelled
        let expectedStatus: PDKExecutionStatus = cleanup ? .blocked : .cancelled
        let capturer = BoundMutatingSourceCapturer(fileName: "pdk.json", mutation: .refuse(error))
        let view = try await LocalPDKManifestViewInspector(sourceCapturer: capturer).execute(fixture.viewRequest())
        #expect(view.status == expectedStatus)
        #expect(view.payload.binding == nil)
        #expect(view.payload.inspection == nil)
        if cleanup { #expect(view.payload.findings.first?.message.contains("cleanup") == true) }

        let ruleRequest = fixture.ruleRequest()
        let rule = try await LocalPDKRuleDeckInspector(sourceCapturer: capturer).execute(ruleRequest)
        #expect(rule.status == expectedStatus)
        #expect(rule.payload.sourceArtifact == nil)
        #expect(rule.payload.statementCount == 0)
        if cleanup { #expect(rule.payload.findings.first?.message.contains("cleanup") == true) }

        let local = try await LocalPDKRuleDeckInspector().execute(ruleRequest)
        let external = try await ExternalPDKRuleDeckInspector(
            provider: BoundRuleResultProvider(data: try JSONEncoder().encode(local)), sourceCapturer: capturer
        ).execute(ruleRequest)
        #expect(external.status == expectedStatus)
        #expect(!external.payload.isValid)
        if cleanup { #expect(external.payload.findings.first?.message.contains("cleanup") == true) }

        let oracleRequest = try fixture.oracleRequest()
        let oracle = try await LocalPDKOracleComparator(
            sourceCapturer: BoundMutatingSourceCapturer(fileName: "oracle.json", mutation: .refuse(error))
        ).execute(oracleRequest)
        #expect(oracle.status == expectedStatus)
        #expect(oracle.payload.comparisons.isEmpty)
        #expect(oracle.payload.oracleArtifact == nil)
        if cleanup { #expect(oracle.payload.findings.first?.message.contains("cleanup") == true) }
    }

    @Test("Oracle preserves nested manifest cancellation and cleanup blockers", arguments: [false, true])
    func nestedManifestCancellationIsPreserved(cleanup: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let request = try fixture.oracleRequest()
        let error: PDKSourceCaptureError = cleanup
            ? .cleanup(primary: .cancelled, cleanup: .invalidTermination) : .cancelled
        let result = try await LocalPDKOracleComparator(
            manifestInspector: LocalPDKManifestViewInspector(
                sourceCapturer: BoundMutatingSourceCapturer(fileName: "pdk.json", mutation: .refuse(error))
            )
        ).execute(request)
        #expect(result.status == (cleanup ? .blocked : .cancelled))
        #expect(!result.payload.isValid)
        #expect(result.payload.oracleArtifact == request.oracle)
        if cleanup {
            #expect(result.payload.findings.contains { $0.message.contains("cleanup") })
        } else {
            #expect(result.payload.comparisons.isEmpty)
        }
    }

    @Test("Oracle preserves a thrown nested cancellation")
    func thrownNestedCancellationIsPreserved() async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let request = try fixture.oracleRequest()
        let result = try await LocalPDKOracleComparator(
            manifestInspector: BoundThrowingManifestInspector()
        ).execute(request)
        #expect(result.status == .cancelled)
        #expect(result.payload.oracleArtifact == request.oracle)
        #expect(result.payload.comparisons.isEmpty)
        #expect(result.payload.findings.contains { $0.code == "pdk.oracle.view-execution-cancelled" })
    }

    @Test("Rule text cleanup after cancellation is preserved as a capture blocker")
    func ruleTextCleanupIsRefused() async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let result = try await LocalPDKRuleDeckInspector(
            sourceCapturer: BoundMutatingSourceCapturer(
                fileName: "rules.deck", mutation: .refuse(.cleanup(primary: .cancelled, cleanup: .invalidTermination))
            )
        ).execute(fixture.ruleRequest())
        #expect(result.status == .blocked)
        #expect(result.payload.statementCount == 0)
        #expect(result.payload.sourceArtifact == nil)
        #expect(result.payload.findings.first?.code == "pdk.validation.rule-deck-capture-failed")
        #expect(result.payload.findings.first?.message.contains("cleanup") == true)
    }
}
