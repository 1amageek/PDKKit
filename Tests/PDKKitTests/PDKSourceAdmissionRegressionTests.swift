import CircuiteFoundation
import Foundation
import PDKCore
import PDKStandardViews
import Testing

struct PDKSourceAdmissionRegressionTests {
    @Test("Manifest binding rejects changed source bytes before parsing")
    func changedViewCannotReplaceResolvedIdentity() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.copyItem(at: PDKTestFixtures.validPDKURL, to: root)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record("Fixture cleanup failed: \(error)") }
        }
        let pdk = try await loadPDKReference(for: root.appending(path: "pdk.json"))
        let result = try await LocalPDKManifestViewInspector(
            assetResolver: MutatingViewAssetResolver()
        ).execute(PDKManifestViewInspectionRequest(
            runID: "view-source-race", inputs: [pdk.manifestLocator],
            pdk: pdk, assetID: "cells", format: .lef
        ))
        #expect(result.status == .blocked)
        #expect(result.payload.binding == nil)
        #expect(result.payload.inspection?.inspection == nil)
        #expect(result.payload.findings.contains { $0.code == "pdk.standard-view.digest-mismatch" })
    }

    @Test("Rule text changed after resolution cannot execute under the original content identity")
    func changedRuleBytesAreRefused() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.copyItem(at: PDKTestFixtures.validPDKURL, to: root)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record("Fixture cleanup failed: \(error)") }
        }
        let manifest = root.appending(path: "pdk.json")
        let reference = try await loadPDKReference(for: manifest)
        let result = try await LocalPDKRuleDeckInspector(
            assetResolver: MutatingRuleAssetResolver()
        ).execute(PDKRuleDeckInspectionRequest(
            runID: "rule-source-race", inputs: [reference.manifestLocator],
            pdk: reference, assetID: "rules"
        ))
        #expect(result.status == .blocked)
        #expect(!result.payload.isValid)
        #expect(result.payload.findings.contains {
            $0.code == "pdk.validation.rule-deck-asset-digest-mismatch"
        })
    }
}
