import Testing
@testable import PDKCore
@testable import PDKDiscovery
@testable import PDKValidation
@testable import PDKKit
@testable import PDKKitCLICore

@Suite("PDKKit contract")
struct ContractTests {
    @Test("contract version starts at one")
    func contractVersion() {
        #expect(PDKKitAPI.contractVersion == 1)
        #expect(PDKKitCLICoreAPI.contractVersion == 1)
        #expect(PDKKitAPI.manifestSchemaVersion == PDKManifest.currentSchemaVersion)
        #expect(PDKKitAPI.corpusValidationStageID == "pdk.validate-corpus")
        #expect(PDKKitAPI.standardViewInspectionStageID == "pdk.inspect-standard-view")
    }
}
