import Foundation
import PDKCore
import PDKKitCLICore
import PDKProfileAdmission
import PDKSpiceProfileInspection
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ProfileCLIWorkflowTests {
    @Test func jsonOnlyProposalUsesActualEmptyPreprocessingIdentityThroughAdmissionAndReplay() async throws {
        var fixture = try await ProfileCLIFixture.make(jsonOnly: true)
        defer { fixture.cleanup() }
        #expect(fixture.bindings.count == 1)
        #expect(!FileManager.default.fileExists(atPath: fixture.root.rootURL.appending(path: "root.sp").path))
        let proposed = try await fixture.invoke("propose")
        let definition = try ProfileCLIFixture.field(PDKProfileDefinition.self, name: "definition", in: proposed)
        #expect(definition.sources.count == 1)
        #expect(definition.sources.first?.reference.descriptor.format == .json)
        #expect(definition.dependencies.isEmpty)
        #expect(!definition.initialPreprocessingIdentity.isEmpty)
        #expect(definition.initialPreprocessingIdentity != ProfileCLIFixture.policy)
        let resources = LocalPDKAdmissionResources(budget: fixture.budget)
        defer { resources.close() }
        let initial = try LocalPDKSpiceCandidateDiscoverer(policyIdentity: ProfileCLIFixture.policy)
            .initialPreprocessingIdentity(resources: resources)
        #expect(definition.initialPreprocessingIdentity == initial.identity)
        try await fixture.adopt(definition)
        let admitted = try await fixture.invoke("admit")
        let claim = try ProfileCLIFixture.field(PDKProfileClaim.self, name: "claim", in: admitted)
        #expect(claim.definition == definition)
        #expect(claim.sourceClosure.count == 1)
        #expect(claim.selections.count == 1)
        try await fixture.retain(claim)
        let replayed = try await fixture.invoke("replay")
        let replayClaim = try ProfileCLIFixture.field(PDKProfileClaim.self, name: "claim", in: replayed)
        #expect(replayClaim == claim)
        withExtendedLifetime(initial) {}
    }

    @Test func ownedInvocationProposesAdoptsPlansAdmitsAndReplaysRealMixedSources() async throws {
        var fixture = try await ProfileCLIFixture.make()
        defer { fixture.cleanup() }
        #expect(fixture.definitionBinding == nil)
        #expect(!FileManager.default.fileExists(atPath: fixture.root.rootURL.appending(path: "profile.json").path))
        let proposed = try await fixture.invoke("propose")
        let definition = try ProfileCLIFixture.field(PDKProfileDefinition.self, name: "definition", in: proposed)
        #expect(definition.profileID == "cli-profile")
        #expect(definition.sources.count == 3)
        #expect(definition.dependencies.count == 1)
        let edge = try #require(definition.dependencies.first)
        #expect(edge.parentSourceKey == "root")
        #expect(edge.childSourceKey == "child")
        #expect(edge.literalRoute == "child.sp")
        #expect(edge.childReference == fixture.sourceReferences["child"])
        #expect(!FileManager.default.fileExists(atPath: fixture.root.rootURL.appending(path: "profile.json").path))
        try await fixture.adopt(definition)
        let planned = try await fixture.invoke("plan")
        #expect(planned["plan"] != nil)
        let admitted = try await fixture.invoke("admit")
        let claim = try ProfileCLIFixture.field(PDKProfileClaim.self, name: "claim", in: admitted)
        #expect(claim.definition == definition)
        #expect(claim.definitionReference == fixture.definitionBinding?.reference)
        #expect(claim.sourceClosure.count == 3)
        #expect(claim.selections.count == 2)
        #expect(claim.dependencies == definition.dependencies)
        #expect(!FileManager.default.fileExists(atPath: fixture.root.rootURL.appending(path: "claim.json").path))
        try await fixture.retain(claim)
        let replayed = try await fixture.invoke("replay")
        let replayClaim = try ProfileCLIFixture.field(PDKProfileClaim.self, name: "claim", in: replayed)
        #expect(replayClaim == claim)
        #expect(replayClaim.semanticSelectionDigest == claim.semanticSelectionDigest)
        #expect(admitted["operationalObservations"] != nil)
        #expect(replayed["operationalObservations"] != nil)
    }

    @Test func executableCompletesRealProposePlanAdmissionAndRetainedReplay() async throws {
        let executable = try ProfileCLIFixture.executable()
        var fixture = try await ProfileCLIFixture.make()
        defer { fixture.cleanup() }
        let proposed = try await fixture.execute("propose", executable: executable)
        #expect(proposed.exitCode == 0)
        #expect(proposed.standardError.isEmpty)
        let definition = try ProfileCLIFixture.field(PDKProfileDefinition.self, name: "definition",
            in: ProfileCLIFixture.envelope(proposed.standardOutput))
        #expect(definition.dependencies.count == 1)
        try await fixture.adopt(definition)
        let planned = try await fixture.execute("plan", executable: executable)
        #expect(planned.exitCode == 0)
        #expect(try ProfileCLIFixture.envelope(planned.standardOutput)["plan"] != nil)
        let admitted = try await fixture.execute("admit", executable: executable)
        #expect(admitted.exitCode == 0)
        #expect(admitted.standardError.isEmpty)
        let claim = try ProfileCLIFixture.field(PDKProfileClaim.self, name: "claim",
            in: ProfileCLIFixture.envelope(admitted.standardOutput))
        #expect(claim.sourceClosure.count == 3)
        try await fixture.retain(claim)
        let replayed = try await fixture.execute("replay", executable: executable)
        #expect(replayed.exitCode == 0)
        #expect(replayed.standardError.isEmpty)
        let replayClaim = try ProfileCLIFixture.field(PDKProfileClaim.self, name: "claim",
            in: ProfileCLIFixture.envelope(replayed.standardOutput))
        #expect(replayClaim == claim)
    }
}
