import Foundation
import PDKCore
import PDKProfileAdmission
import PDKSpiceProfileInspection
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SpiceProfileRefusalTests {
    @Test func temperaturesRemainDistinctAndNoDefaultsAreInvented() async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root":
            "* root\n.temp 25\n.option tnom=30\n.model m NMOS (level=1 tnom=27)\n"], demands: ["devices", "operatingTemperature"])
        defer { fixture.remove() }
        let facts = try await fixture.admit().sourceFacts[0]
        #expect(facts.pvt.isEmpty)
        #expect(facts.temperatures.contains { $0.kind == "operatingTemperature" && $0.temperatureCelsius == 25 })
        #expect(facts.temperatures.contains { $0.kind == "modelNominalTemperature" && $0.temperatureCelsius == 27 })
        #expect(facts.temperatures.contains { $0.kind == "circuitNominalTemperature" && $0.temperatureCelsius == 30 })
        let leaf = try await SpiceProfileFixture.make()
        defer { leaf.remove() }
        #expect(try await leaf.admit().sourceFacts[0].temperatures.isEmpty)
    }
    @Test(arguments: [".temp {25+1}", ".option tnom={25+1}", ".model m D (tnom={25+1})"])
    func temperatureExpressionsAreExplicitlyUnsupported(statement: String) async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root": "* root\n" + statement + "\n.model m D\n"])
        defer { fixture.remove() }
        await #expect(throws: PDKProfileAdmissionError.inspection(.unsupportedSemantics)) { try await fixture.admit() }
    }
    @Test func requiredSourcePVTDoesNotUseExpectedCorner() async throws {
        let fixture = try await SpiceProfileFixture.make(demands: ["devices", "sourcePVT"])
        defer { fixture.remove() }
        await #expect(throws: PDKProfileAdmissionError.inspection(.unsupportedSemantics)) { try await fixture.admit() }
    }
    @Test func absentOperatingTemperatureDoesNotUseParserDefault() async throws {
        let fixture = try await SpiceProfileFixture.make(demands: ["devices", "operatingTemperature"])
        defer { fixture.remove() }
        await #expect(throws: PDKProfileAdmissionError.missingCoverage) { try await fixture.admit() }
    }
    @Test func modelExpressionRetainsCoreFormatting() async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root": "* root\n.model m NMOS (level=1 vto={base+0.1})\n"])
        defer { fixture.remove() }
        let facts = try await fixture.admit().sourceFacts[0]
        let parameter = try #require(facts.mappings[0].model?.parameters.first { $0.name == "vto" })
        #expect(parameter.value == .expression("(base + 0.1)"))
    }
    @Test func actualInitialEnvironmentMustMatch() async throws {
        let fixture = try await SpiceProfileFixture.make(initialIdentity: "foreign.environment")
        defer { fixture.remove() }
        await #expect(throws: PDKProfileAdmissionError.inspection(.invalidFacts)) { try await fixture.admit() }
    }
    @Test func cycleKeepsTypedAdmissionCause() async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root": "* root\n.include child.sp\n.model m D\n",
            "child": "* child\n.include root.sp\n"], edges: [
                .init(parent: "root", child: "child", offset: 7, ordinal: 0),
                .init(parent: "child", child: "root", offset: 8, ordinal: 0)])
        defer { fixture.remove() }
        await #expect(throws: PDKProfileAdmissionError.contextualCycle) { try await fixture.admit() }
    }
    @Test func disabledIncludeResolutionCannotPublishLeaf() async throws {
        let fixture = try await SpiceProfileFixture.make()
        defer { fixture.remove() }
        let inspector = LocalPDKSpiceProfileInspector(policyIdentity: SpiceProfileFixture.policy,
            configuration: .init(resolveIncludes: false))
        await #expect(throws: PDKProfileAdmissionError.inspection(.invalidFacts)) { try await fixture.admit(inspector: inspector) }
    }
    @Test func syntaxFailureRetainsPhysicalSelectedLocation() async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root":
            "* root\n.lib TT\n.model m D\n.model broken\n.endl TT\n"], selectedSection: "TT")
        defer { fixture.remove() }
        do { _ = try await fixture.admit(); Issue.record("Malformed source admitted") }
        catch let error as PDKProfileAdmissionError {
            guard case .inspection(.syntax(let syntax)) = error.underlyingReason else {
                Issue.record("Syntax cause lost: \(error)"); return
            }
            #expect(syntax.sourceKey == "root")
            #expect(syntax.line == 4)
            #expect(syntax.column != nil)
            #expect(!syntax.diagnostic.summary.isEmpty)
        }
    }
}
