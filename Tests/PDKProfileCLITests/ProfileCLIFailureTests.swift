import Foundation
import PDKCore
import PDKKitCLICore
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ProfileCLIFailureTests {
    private func adopted() async throws -> ProfileCLIFixture {
        var fixture = try await ProfileCLIFixture.make()
        do {
            let output = try await fixture.invoke("propose")
            let definition = try ProfileCLIFixture.field(PDKProfileDefinition.self, name: "definition", in: output)
            try await fixture.adopt(definition)
            return fixture
        } catch {
            fixture.cleanup()
            throw error
        }
    }

    @discardableResult private func refused(_ fixture: ProfileCLIFixture, _ verb: String) async throws -> PDKProfileCommandError {
        let result = await PDKKitCLI.invoke(arguments: fixture.arguments(verb))
        #expect(result.exitCode != 0)
        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.isEmpty)
        let profile = try #require(result.profileResult)
        let error = try #require(profile.failure)
        #expect(profile.isStandardError)
        if let output = profile.output {
            let envelope = try ProfileCLIFixture.envelope(ProfileCLIFixture.data(output))
            #expect(envelope["claim"] == nil || envelope["claim"] is NSNull)
        }
        return error
    }

    @Test func changedDependencyBytesRefuseAdmission() async throws {
        let fixture = try await adopted()
        defer { fixture.cleanup() }
        try Data("* actual dependency\n.model child PMOS (level=1 vto=-0.5)\n".utf8)
            .write(to: fixture.root.rootURL.appending(path: "child.sp"))
        try await refused(fixture, "admit")
    }

    @Test func changedExactManifestRefusesPlanning() async throws {
        let fixture = try await adopted()
        defer { fixture.cleanup() }
        let url = fixture.root.rootURL.appending(path: "pdk.json")
        var bytes = try Data(contentsOf: url); bytes.append(32)
        try bytes.write(to: url)
        try await refused(fixture, "plan")
    }

    @Test func changedExactDefinitionRefusesAdmission() async throws {
        let fixture = try await adopted()
        defer { fixture.cleanup() }
        let url = fixture.root.rootURL.appending(path: "profile.json")
        var bytes = try Data(contentsOf: url); bytes.append(32)
        try bytes.write(to: url)
        try await refused(fixture, "admit")
    }

    @Test func missingDependencyAvailabilityRefusesAdmission() async throws {
        var fixture = try await adopted()
        defer { fixture.cleanup() }
        try await fixture.refreshAvailability(sources: fixture.bindings.filter { $0.sourceKey != "child" })
        try await refused(fixture, "admit")
    }

    @Test func obsoleteOperationalSchemaRefusesBeforeProfileWork() async throws {
        var fixture = try await ProfileCLIFixture.make()
        defer { fixture.cleanup() }
        var wire = try ProfileCLIFixture.envelope(Data(contentsOf: fixture.root.rootURL.appending(path: "availability.json")))
        wire["schemaVersion"] = 2
        fixture.availabilityBinding = try await fixture.write(JSONSerialization.data(withJSONObject: wire),
            name: "availability.json", descriptor: PDKProfileCLIAvailability.artifactDescriptor)
        try await refused(fixture, "propose")
    }

    @Test func checkedButDifferentRetainedClaimRefusesFullReplayComparison() async throws {
        var fixture = try await adopted()
        defer { fixture.cleanup() }
        let admitted = try await fixture.invoke("admit")
        let claim = try ProfileCLIFixture.field(PDKProfileClaim.self, name: "claim", in: admitted)
        let original = claim.definition
        let altered = try PDKProfileDefinition(profileID: "foreign-profile", manifestReference: original.manifestReference,
            processID: original.processID, version: original.version, requiredCornerIDs: original.requiredCornerIDs,
            requirements: original.requirements, sources: original.sources, orderedSearchRoutes: original.orderedSearchRoutes,
            dependencies: original.dependencies, inspectionPolicyIdentity: original.inspectionPolicyIdentity,
            initialPreprocessingIdentity: original.initialPreprocessingIdentity)
        let alteredPlan = try PDKProfilePlan(definition: altered, manifest: fixture.manifest,
            manifestReference: fixture.manifestBinding.reference)
        let wrong = try PDKProfileClaim(definitionReference: claim.definitionReference, plan: alteredPlan)
        #expect(wrong != claim)
        #expect(wrong.semanticSelectionDigest != claim.semanticSelectionDigest)
        #expect(try PDKProfileCodec().decodeClaim(PDKProfileCodec().encodeClaim(wrong)) == wrong)
        try await fixture.retain(wrong)
        let failure = try await refused(fixture, "replay")
        guard case .replayMismatch = failure else {
            Issue.record("Expected full retained-claim comparison failure"); return
        }
    }

    @Test func changedRetainedClaimBytesRefuseReplay() async throws {
        var fixture = try await adopted()
        defer { fixture.cleanup() }
        let admitted = try await fixture.invoke("admit")
        let claim = try ProfileCLIFixture.field(PDKProfileClaim.self, name: "claim", in: admitted)
        try await fixture.retain(claim)
        let url = fixture.root.rootURL.appending(path: "claim.json")
        var bytes = try Data(contentsOf: url); bytes.append(32)
        try bytes.write(to: url)
        try await refused(fixture, "replay")
    }

    @Test func invocationReadBudgetAccumulatesAcrossOperationalAndSemanticInputs() async throws {
        let fixture = try await adopted()
        defer { fixture.cleanup() }
        let definition = try #require(fixture.definitionBinding)
        let largestIndividual = max(fixture.availabilityBinding.reference.byteCount,
            fixture.manifestBinding.reference.byteCount, definition.reference.byteCount)
        let budget = try ProfileCLIFixture.makeBudget(overrides: [.readBytes: largestIndividual + 1])
        try JSONEncoder().encode(budget).write(to: fixture.root.rootURL.appending(path: "budget.json"))
        try await refused(fixture, "admit")
    }

    @Test func executableReturnsNonzeroForRealMissingDependency() async throws {
        let executable = try ProfileCLIFixture.executable()
        var fixture = try await adopted()
        defer { fixture.cleanup() }
        try await fixture.refreshAvailability(sources: fixture.bindings.filter { $0.sourceKey != "child" })
        let result = try await fixture.execute("admit", executable: executable)
        #expect(result.exitCode != 0)
        #expect(result.standardOutput.isEmpty)
        #expect(!result.standardError.isEmpty)
        let envelope = try ProfileCLIFixture.envelope(result.standardError)
        #expect(envelope["claim"] == nil || envelope["claim"] is NSNull)
    }
}
