import PDKCore
import PDKProfileAdmission
import PDKSpiceProfileInspection
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SpiceProfileResourceTests {
    private func amount(_ resources: LocalPDKAdmissionResources, _ dimension: PDKAdmissionResourceDimension) throws -> UInt64 {
        guard let observation = try resources.snapshot().dimensions.first(where: { $0.dimension == dimension }) else {
            Issue.record("Missing observation"); return 0
        }
        switch observation.usage {
        case .cumulative(let total): return total
        case .live(let current, _): return current
        }
    }
    @Test func realReadAndHashWorkRemainDistinct() async throws {
        let fixture = try await SpiceProfileFixture.make(files: ["root": "* root\n.include child.sp\n.include child.sp\n.model m D\n",
            "child": "* child\n.subckt cell p n\nR1 p n 1k\n.ends cell\n"], edges: [
                .init(parent: "root", child: "child", offset: 7, ordinal: 0),
                .init(parent: "root", child: "child", offset: 25, ordinal: 1)], logicalNames: ["m", "cell"])
        defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        let admitted = try await fixture.admit(resources: resources)
        #expect(try amount(resources, .readBytes) == fixture.readBytes)
        #expect(try amount(resources, .hashedBytes) > fixture.readBytes)
        #expect(try amount(resources, .parserWork) > 0)
        #expect(admitted.sourceFacts[0].events.count == 2)
    }
    @Test(arguments: [PDKAdmissionResourceDimension.parserWork, .hashedBytes, .liveOwnedBytes, .temporaryBytes])
    func quotaRefusalIsTyped(dimension: PDKAdmissionResourceDimension) async throws {
        let fixture = try await SpiceProfileFixture.make()
        defer { fixture.remove() }
        let budget = try SpiceProfileFixture.budget(overrides: [dimension: 1])
        let resources = LocalPDKAdmissionResources(budget: budget); defer { resources.close() }
        do { _ = try await fixture.admit(resources: resources); Issue.record("Quota ignored") }
        catch let error as PDKProfileAdmissionError {
            if case .resource(.exhausted(let observed, _, _)) = error.underlyingReason { #expect(observed == dimension) }
            else if case .definition(.resource(.exhausted(let observed, _, _))) = error.underlyingReason { #expect(observed == dimension) }
            else if case .source(.resource(.exhausted(let observed, _, _))) = error.underlyingReason { #expect(observed == dimension) }
            else if case .inspection(.resource(.exhausted(let observed, _, _))) = error.underlyingReason { #expect(observed == dimension) }
            else { Issue.record("Quota cause lost: \(error)") }
        }
    }
    @Test func cancellationRefusesPublication() async throws {
        let fixture = try await SpiceProfileFixture.make()
        defer { fixture.remove() }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await fixture.admit()
        }
        do { _ = try await task.value; Issue.record("Cancelled profile admitted") }
        catch let error as PDKProfileAdmissionError { #expect(error.isCancellation) }
    }
    @Test func factsFinalCopyRetainsCapacityAfterParseOwnerRelease() async throws {
        let fixture = try await SpiceProfileFixture.make()
        defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.request.budget); defer { resources.close() }
        var owner: AdmittedPDKProfile? = try await fixture.admit(resources: resources)
        var facts: PDKProfileSourceFacts? = owner!.sourceFacts[0]
        owner = nil
        let retained = try amount(resources, .liveOwnedBytes)
        #expect(retained > 0)
        #expect(facts!.mappings[0].model?.type == "NMOS")
        facts = nil
        #expect(try amount(resources, .liveOwnedBytes) == 0)
    }

    @Test func finalFactsCopyRefusesBeforeCapacityAllocation() async throws {
        let fixture = try await SpiceProfileFixture.make()
        defer { fixture.remove() }
        let actual = try await fixture.admit().sourceFacts[0]
        let resources = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget(overrides: [.liveOwnedBytes: 1]))
        defer { resources.close() }
        #expect(throws: PDKProfileInspectionError.self) {
            try PDKProfileSourceFacts(input: actual.input, parserIdentity: actual.parserIdentity,
                policyIdentity: actual.policyIdentity, mappings: actual.mappings, pvt: actual.pvt,
                temperatures: actual.temperatures, coverage: actual.coverage, events: actual.events,
                unsupportedFactKinds: [], lostFactKinds: [], resources: resources)
        }
        #expect(try amount(resources, .liveOwnedBytes) == 0)
    }
    @Test func adapterCapacityRefusalKeepsExactTypedCause() async throws {
        let fixture = try await SpiceProfileFixture.make()
        defer { fixture.remove() }
        let inspector = RefusingSpiceAdapter()
        await #expect(throws: PDKProfileAdmissionError.inspection(.resource(.exhausted(
            dimension: .temporaryBytes, limit: 0, attempted: 1)))) { try await fixture.admit(inspector: inspector) }
    }
    @Test func diagnosticFinalCopyRetainsCapacityUntilLastCopy() async throws {
        let resources = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget()); defer { resources.close() }
        var original: PDKProfileSyntaxDiagnostic? = try .init(message: "Actual source syntax", sourceKey: "root",
            file: "root.sp", line: 7, column: 3, resources: resources)
        var copied = original
        original = nil
        #expect(copied?.line == 7)
        #expect(try amount(resources, .liveOwnedBytes) > 0)
        copied = nil
        #expect(try amount(resources, .liveOwnedBytes) == 0)
    }
}
