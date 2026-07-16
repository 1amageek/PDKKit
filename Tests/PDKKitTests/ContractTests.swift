import Testing
import CircuiteFoundation
@testable import PDKCore
@testable import PDKDiscovery
@testable import PDKValidation
@testable import PDKStandardViews
@testable import PDKKit
@testable import PDKKitCLICore

@Suite("PDKKit contract")
struct ContractTests {
    @Test("contract version starts at one")
    func contractVersion() {
        #expect(PDKKitAPI.contractVersion == 2)
        #expect(PDKKitCLICoreAPI.contractVersion == 2)
        #expect(PDKKitAPI.manifestSchemaVersion == PDKManifest.currentSchemaVersion)
        #expect(PDKKitAPI.corpusValidationStageID == "pdk.validate-corpus")
        #expect(PDKKitAPI.standardViewInspectionStageID == "pdk.inspect-standard-view")
        #expect(PDKKitAPI.ruleDeckInspectionStageID == "pdk.inspect-rule-deck")
    }

    @Test("domain engines conform directly to the shared engine protocol")
    func directEngineConformance() {
        requireEngine(LocalPDKDiscoverer.self)
        requireEngine(LocalPDKValidator.self)
        requireEngine(LocalPDKCorpusValidator.self)
        requireEngine(LocalPDKStandardViewInspector.self)
        requireEngine(LocalPDKRuleDeckInspector.self)
        requireEngine(LocalPDKManifestViewInspector.self)
        requireEngine(LocalPDKOracleComparator.self)
    }

    @Test("domain results expose shared evidence capabilities")
    func directResultCapabilities() {
        requireEvidenceResult(PDKDiscoveryResult.self)
        requireEvidenceResult(PDKValidationResult.self)
        requireEvidenceResult(PDKCorpusValidationResult.self)
        requireEvidenceResult(PDKStandardViewInspectionResult.self)
        requireEvidenceResult(PDKRuleDeckInspectionResult.self)
        requireEvidenceResult(PDKManifestViewInspectionResult.self)
        requireEvidenceResult(PDKOracleComparisonResult.self)
    }

    private func requireEngine<T: Engine>(_: T.Type) {}

    private func requireEvidenceResult<T>(_: T.Type)
    where T: ArtifactProducing & DiagnosticReporting & EvidenceProviding {}
}
