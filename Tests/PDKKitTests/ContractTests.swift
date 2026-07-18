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
    @Test("operations provide stable flow identifiers")
    func operationIdentifiers() {
        #expect(PDKOperation.corpusValidation.rawValue == "pdk.validate-corpus")
        #expect(PDKOperation.standardViewInspection.rawValue == "pdk.inspect-standard-view")
        #expect(PDKOperation.ruleDeckInspection.rawValue == "pdk.inspect-rule-deck")
        #expect(Set(PDKOperation.allCases.map(\.rawValue)).count == PDKOperation.allCases.count)
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
