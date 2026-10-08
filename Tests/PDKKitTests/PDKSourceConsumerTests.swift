import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import PDKSourceCapture
import PDKStandardViews
import PDKValidation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PDKSourceConsumerTests {
    @Test(arguments: [PDKCapturedSourceMutation.Mutation.replace, .remove])
    func validationDecodesCapturedManifest(_ mutation: PDKCapturedSourceMutation.Mutation) async throws {
        let root = try copiedFixture()
        defer { removeFixture(root) }
        let file = root.appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: file)
        let result = try await LocalPDKValidator(
            sourceCapturer: PDKCapturedSourceMutation(file: file, mutation: mutation)
        ).execute(PDKValidationRequest(
            runID: "captured-manifest", inputs: [], pdk: pdk,
            validateStandardViews: false, validateRuleDecks: false
        ))
        #expect(result.status == .completed, "\(result.diagnostics)")
        #expect(result.payload.isValid)
        #expect(result.provenance.inputs.contains(pdk.manifest))
    }

    @Test(arguments: [PDKCapturedSourceMutation.Mutation.replace, .remove])
    func standardParserUsesCapturedBytes(_ mutation: PDKCapturedSourceMutation.Mutation) async throws {
        let root = try copiedFixture()
        defer { removeFixture(root) }
        let file = root.appending(path: "cells.lef")
        let locator = try ArtifactLocator(
            location: ArtifactLocation(fileURL: file), role: .input, kind: .technology, format: .lef
        )
        let expected = try PDKArtifactReferenceBuilder.artifactReference(for: locator, resolvedURL: file)
        let result = try await LocalPDKStandardViewInspector(
            sourceCapturer: PDKCapturedSourceMutation(file: file, mutation: mutation)
        ).execute(PDKStandardViewInspectionRequest(
            runID: "captured-standard", inputs: [locator], format: .lef, expectedLayerNames: ["M1"]
        ))
        #expect(result.status == .completed, "\(result.diagnostics)")
        #expect(result.payload.inspection?.sourceArtifact == expected)
        #expect(result.payload.inspection?.layerNames.contains("M1") == true)
    }

    @Test
    func changedManifestIsRejectedBeforeDecoding() async throws {
        let root = try copiedFixture()
        defer { removeFixture(root) }
        let file = root.appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: file)
        let original = try Data(contentsOf: file)
        var changed = original
        changed[changed.startIndex] = 33
        try changed.write(to: file, options: .atomic)
        let result = try await LocalPDKValidator().execute(PDKValidationRequest(
            runID: "changed-manifest", inputs: [], pdk: pdk
        ))
        #expect(result.status == .blocked)
        #expect(!result.payload.isValid)
        #expect(result.payload.findings.contains { $0.code == "pdk.validation.manifest-digest-mismatch" })
        #expect(result.payload.standardViewResults.isEmpty)
        #expect(result.payload.ruleDeckResults.isEmpty)
    }

    @Test(arguments: [false, true])
    func cancelledCaptureAndCleanupFailureStayDistinct(_ cleanupFails: Bool) async throws {
        let file = PDKTestFixtures.validPDKURL.appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: file)
        let failure: PDKSourceCaptureError = cleanupFails
            ? .cleanup(primary: .cancelled, cleanup: .invalidTermination) : .cancelled
        let result = try await LocalPDKValidator(
            sourceCapturer: PDKFailingSourceCapturer(failure: failure)
        ).execute(PDKValidationRequest(runID: "capture-failure", inputs: [], pdk: pdk))
        #expect(result.status == (cleanupFails ? .blocked : .cancelled))
        #expect(!result.payload.isValid)
        #expect(result.payload.findings.contains {
            $0.code == (cleanupFails ? "pdk.validation.manifest-capture-failed" : "pdk.validation.manifest-capture-cancelled")
        })
        #expect(result.payload.standardViewResults.isEmpty)
    }

    @Test
    func standardViewCleanupFailureProducesNoParsedPayload() async throws {
        let file = PDKTestFixtures.validPDKURL.appending(path: "cells.lef")
        let locator = try ArtifactLocator(
            location: ArtifactLocation(fileURL: file), role: .input, kind: .technology, format: .lef
        )
        let result = try await LocalPDKStandardViewInspector(
            sourceCapturer: PDKFailingSourceCapturer(failure: .invalidTermination)
        ).execute(PDKStandardViewInspectionRequest(runID: "cleanup-refusal", inputs: [locator], format: .lef))
        #expect(result.status == .blocked)
        #expect(result.payload.inspection == nil)
        #expect(result.payload.findings.contains { $0.code == "pdk.standard-view.capture-failed" })
    }

    private func copiedFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "source-consumer-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: PDKTestFixtures.validPDKURL, to: root)
        return root
    }

    private func removeFixture(_ root: URL) {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record("Fixture cleanup failed: \(error)") }
    }
}
