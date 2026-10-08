import Foundation
import CircuiteFoundation
import CircuiteFoundationCrypto
import Testing
import PDKCore
import PDKDiscovery
import PDKSourceCapture
import PDKValidation
import PDKStandardViews

@Suite("PDK required input semantics", .timeLimit(.minutes(1)))
struct PDKRequiredInputTests {
    @Test("Every requested-role asset is required even when declared optional", arguments: [false, true])
    func requestedRoleCannotDowngradeMissingAsset(requireIdentity: Bool) async throws {
        let root = try temporaryDirectory()
        defer { remove(root) }
        let manifestURL = root.appending(path: "pdk.json")
        var manifest = try PDKManifestCodec.decode(contentsOf: PDKTestFixtures.validPDKURL.appending(path: "pdk.json"))
        manifest.assets.append(PDKAssetReference(
            assetID: "optional-extraction", role: .extraction, path: "absent.json",
            kind: .model, format: .json, required: false,
            sha256: String(repeating: "0", count: 64), byteCount: 1
        ))
        try PDKManifestCodec.encode(manifest, pretty: true).write(to: manifestURL)
        let loaded = try await LocalPDKManifestLoader().discover(
            at: makeArtifactLocator(path: manifestURL.path, kind: .technology, format: .json),
            relativeTo: nil, captureBudget: PDKSourceCapturePolicy.defaultBudget
        )
        let result = try await LocalPDKValidator().execute(PDKValidationRequest(
            runID: "required-optional", inputs: [], pdk: loaded.reference,
            requiredAssetRoles: [.extraction], requireAssetIdentity: requireIdentity,
            validateCrossViews: false, validateStandardViews: false, validateRuleDecks: false
        ))
        #expect(result.status == .blocked)
        #expect(result.payload.findings.contains {
            $0.entity == "optional-extraction" && $0.code == "pdk.validation.required-asset-unavailable"
        })
    }

    @Test("Unsupported dependency and conditional directives block structural SPICE evidence",
           arguments: [".include \"absent.spice\"", ".inc absent.spice", ".lib absent.spice tt", ".if 0\n.include absent.spice\n.endif"])
    func dependencyCannotDisappear(directive: String) async throws {
        let result = try await inspect(directive + "\n.model device nmos level=1\n.end\n")
        #expect(result.status == .blocked)
        #expect(!result.payload.isValid)
        #expect(result.payload.inspection == nil)
        #expect(result.payload.findings.contains { $0.code == "pdk.standard-view.spice-dependency-unsupported" })
    }

    @Test("A supported leaf library section remains valid")
    func leafSectionRemainsValid() async throws {
        let result = try await inspect(".lib tt\n.model device nmos level=1\n.endl tt\n.end\n")
        #expect(result.status == .completed)
        #expect(result.payload.isValid)
        #expect(result.payload.inspection?.cornerNames == ["tt"])
    }

    @Test("Asset resolution cancellation never becomes an optional warning")
    func resolutionCancellationStopsValidation() async throws {
        let manifestURL = PDKTestFixtures.validPDKURL.appending(path: "pdk.json")
        let reference = try await loadPDKReference(for: manifestURL)
        let result = try await LocalPDKValidator(assetResolver: CancellingPDKAssetResolver()).execute(
            PDKValidationRequest(runID: "cancel-resolution", inputs: [], pdk: reference)
        )
        #expect(result.status == .cancelled)
        #expect(result.payload.standardViewResults.isEmpty)
        #expect(result.payload.ruleDeckResults.isEmpty)
        #expect(!result.payload.isValid)
        #expect(result.payload.findings.contains { $0.code == "pdk.validation.asset-resolution-cancelled" })
        #expect(!result.payload.findings.contains { $0.code == "pdk.validation.optional-asset-unavailable" })
    }

    private func inspect(_ text: String) async throws -> PDKStandardViewInspectionResult {
        let root = try temporaryDirectory()
        defer { remove(root) }
        let file = root.appending(path: "view.spice")
        let data = Data(text.utf8)
        try data.write(to: file)
        let binding = try makeArtifactBinding(path: file.path, kind: .model, format: .spice,
            sha256: SHA256ContentDigester().digest(data: data, using: .sha256).hexadecimalValue,
            byteCount: Int64(data.count))
        return try await LocalPDKStandardViewInspector().execute(PDKStandardViewInspectionRequest(
            runID: "required-dependency", inputs: [binding.locator], format: .spice,
            expectedSourceArtifact: binding.reference
        ))
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "pdk-required-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: PDKTestFixtures.validPDKURL, to: root)
        return root
    }

    private func remove(_ root: URL) {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record("Failed to remove required-input fixture: \(error)") }
    }
}
