import Foundation
import PDKCore
import PDKProfileAdmission
import PDKSpiceProfileInspection
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SpiceProfileAdmissionTests {
    @Test func binnedAndUnsupportedUnusedCardsRemainRawInventory() async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root": """
        * inventory is independent of instance selection and execution
        .model process.1 NMOS level=1 lmin=0.1u lmax=2u vto=0.4
        .model process.2 NMOS level=1 lmin=3u lmax=5u vto=0.9
        .model unused NMOS level=54 version=4.5 vth0={missing_numeric_binding}
        """], logicalNames: ["process.1", "process.2", "unused"])
        defer { fixture.remove() }
        let facts = try await fixture.admit().sourceFacts[0]
        #expect(facts.mappings.map(\.name) == ["process.1", "process.2", "unused"])
        #expect(facts.mappings.allSatisfy { $0.terminals.isEmpty && $0.origin != nil })
        let unused = try #require(facts.mappings.first { $0.name == "unused" })
        #expect(unused.model?.parameters.contains { $0.name == "vth0" && $0.value == .expression("missing_numeric_binding") } == true)
    }

    @Test func nestedIncludeOriginsAndModelValues() async throws {
        let fixture = try await SpiceProfileFixture.make(files: [
            "root": "* root\n.include child.sp\n.model m NMOS (level=1 vto=0.4)\n",
            "child": "* child\n.include grand.sp\n.subckt cell z a\nR1 z a 1k\n.ends cell\n",
            "grand": "* grand\n.model g D (is=1e-14)\n"], edges: [
                .init(parent: "root", child: "child", offset: 7, ordinal: 0),
                .init(parent: "child", child: "grand", offset: 8, ordinal: 0)], logicalNames: ["m", "g", "cell"])
        defer { fixture.remove() }
        let admitted = try await fixture.admit()
        let facts = admitted.sourceFacts[0]
        #expect(facts.events.count == 2)
        #expect(facts.coverage.count == 3)
        let model = try #require(facts.mappings.first { $0.name == "g" })
        #expect(model.input.sourceKey == "grand")
        #expect(model.origin?.statementByteOffset == 8)
        #expect(model.origin?.line == 2)
        #expect(model.model?.type == "D")
        #expect(model.terminals.isEmpty)
        #expect(model.model?.parameters.contains { $0.name == "is" && $0.value == .numeric(1e-14) } == true)
        let subcircuit = try #require(facts.mappings.first { $0.name == "cell" })
        #expect(subcircuit.input.sourceKey == "child")
        #expect(subcircuit.terminals == ["z", "a"])
        #expect(subcircuit.origin?.statementByteOffset == 26)
    }
    @Test func selectedParentFullIncludeHasNoChildSection() async throws {
        let fixture = try await SpiceProfileFixture.make(files: [
            "root": "* root\n.lib TT\n.include child.sp\n.model m D\n.endl TT\n.lib SS\n.include absent.sp\n.endl SS\n",
            "child": "* child\n.model c D\n"], edges: [.init(parent: "root", child: "child", offset: 15, ordinal: 0)],
            selectedSection: "TT", demands: ["devices", "selectedSection", "dependencyClosure"], logicalNames: ["m", "c"])
        defer { fixture.remove() }
        let facts = try await fixture.admit().sourceFacts[0]
        #expect(facts.events[0].childContext.selectedSection == nil)
        #expect(facts.coverage.first { $0.input.sourceKey == "root" }?.observedSection == "TT")
        #expect(facts.coverage.first { $0.input.sourceKey == "child" }?.observedSection == nil)
    }
    @Test func externalLibraryUsesExactSelectedChild() async throws {
        let fixture = try await SpiceProfileFixture.make(files: [
            "root": "* root\n.lib child.sp FF\n.model m D\n",
            "child": "* child\n.lib TT\n.model ignored D\n.endl TT\n.lib FF\n.model c D\n.endl FF\n"],
            edges: [.init(parent: "root", child: "child", offset: 7, ordinal: 0, section: "ff", kind: "externalLibrary")],
            logicalNames: ["m", "c"])
        defer { fixture.remove() }
        let facts = try await fixture.admit().sourceFacts[0]
        #expect(facts.events[0].edge.selectedSection == "ff")
        #expect(facts.mappings.contains { $0.name == "c" && $0.input.sourceKey == "child" })
        #expect(!facts.mappings.contains { $0.name == "ignored" })
        #expect(facts.mappings.first { $0.name == "c" }?.origin?.line == 6)
    }
    @Test func repeatedContentKeepsDistinctOccurrenceInputs() async throws {
        let fixture = try await SpiceProfileFixture.make(files: [
            "root": "* root\n.include child.sp\n.include child.sp\n.model m D\n",
            "child": "* child\n.subckt cell p n\nR1 p n 1k\n.ends cell\n"], edges: [
                .init(parent: "root", child: "child", offset: 7, ordinal: 0),
                .init(parent: "root", child: "child", offset: 25, ordinal: 1)], logicalNames: ["m", "cell"])
        defer { fixture.remove() }
        let facts = try await fixture.admit().sourceFacts[0]
        #expect(facts.events.count == 2)
        #expect(facts.coverage.filter { $0.input.sourceKey == "child" }.count == 2)
        let cells = facts.mappings.filter { $0.name == "cell" }
        #expect(cells.count == 2)
        #expect(cells[0].input.incomingEvent?.edge.statementOrdinal == 0)
        #expect(cells[1].input.incomingEvent?.edge.statementOrdinal == 1)
        #expect(cells[0].origin == cells[1].origin)
    }
    @Test func actualParentParameterEnvironmentIsInherited() async throws {
        let fixture = try await SpiceProfileFixture.make(files: [
            "root": "* root\n.param enabled=1\n.include child.sp\n.model m D\n",
            "child": "* child\n.if (enabled)\n.model inherited D\n.else\n.include absent.sp\n.endif\n"],
            edges: [.init(parent: "root", child: "child", offset: 24, ordinal: 1,
                parameters: [.init(name: "enabled", expression: "1.0")])], logicalNames: ["m", "inherited"])
        defer { fixture.remove() }
        let facts = try await fixture.admit().sourceFacts[0]
        #expect(facts.events.count == 1)
        #expect(facts.events[0].childContext.preprocessingIdentity != facts.input.context.preprocessingIdentity)
        #expect(facts.mappings.contains { $0.name == "inherited" })
        #expect(facts.coverage.first { $0.input.sourceKey == "child" }?.inactiveStatementOffsets == [41, 66])
    }
    @Test func inactiveConditionalDoesNotAcquireMissingChild() async throws {
        let fixture = try await SpiceProfileFixture.make(files: [
            "root": "* root\n.if (0)\n.include absent.sp\n.else\n.model m D\n.endif\n"])
        defer { fixture.remove() }
        let facts = try await fixture.admit().sourceFacts[0]
        #expect(facts.events.isEmpty)
        #expect(facts.coverage[0].inactiveStatementOffsets == [7])
    }
    @Test(arguments: [false, true]) func missingAndChangedChildPreserveAdmissionCause(changed: Bool) async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root": "* root\n.include child.sp\n.model m D\n", "child": "* child\n.model c D\n"],
            edges: [.init(parent: "root", child: "child", offset: 7, ordinal: 0)])
        defer { fixture.remove() }
        if changed { try Data("* child\n.model d D\n".utf8).write(to: fixture.root.appending(path: "child.sp")) }
        else { try FileManager.default.removeItem(at: fixture.root.appending(path: "child.sp")) }
        do { _ = try await fixture.admit(); Issue.record("Invalid child admitted") }
        catch let error as PDKProfileAdmissionError {
            if case .source = error.underlyingReason {} else { Issue.record("Source cause lost: \(error)") }
        }
    }
    @Test func undeclaredDependencyRefusesBeforeAcquisition() async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root": "* root\n.include extra.sp\n.model m D\n"])
        defer { fixture.remove() }
        await #expect(throws: PDKProfileAdmissionError.dependencyDrift) { try await fixture.admit() }
    }
    @Test func unconsumedExpectedChildRefuses() async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root": "* root\n.model m D\n", "child": "* child\n.model c D\n"],
            edges: [.init(parent: "root", child: "child", offset: 7, ordinal: 0)])
        defer { fixture.remove() }
        await #expect(throws: PDKProfileAdmissionError.dependencyDrift) { try await fixture.admit() }
    }
}
