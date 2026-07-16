import Foundation
import Testing
@testable import PDKKitCLICore

@Suite("PDKKit CLI")
struct PDKCLITests {
    @Test("inspect returns stable JSON for the same manifest")
    func inspectIsDeterministic() async {
        let path = fixtureURL().appending(path: "pdk.json").path
        let first = await PDKKitCLI.invoke(arguments: ["inspect", "--manifest", path])
        let second = await PDKKitCLI.invoke(arguments: ["inspect", "--manifest", path])
        #expect(first.exitCode == 0)
        #expect(first.standardOutput == second.standardOutput)
        #expect(first.standardError.isEmpty)
    }

    @Test("invalid CLI arguments produce one structured stderr object")
    func invalidArgumentsAreStructured() async throws {
        let result = await PDKKitCLI.invoke(arguments: ["validate"])
        #expect(result.exitCode == 1)
        let data = try #require(result.standardError.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        let dictionary = try #require(object as? [String: String])
        #expect(dictionary["code"] == "pdkkit.cli.invalid-arguments")
    }

    @Test("corpus returns deterministic retained-case output")
    func corpusIsDeterministic() async throws {
        let rootPath = fixtureRootURL().path
        let suitePath = fixtureRootURL().appending(path: "pdk-corpus.json").path
        let first = await PDKKitCLI.invoke(arguments: [
            "corpus", "--suite", suitePath, "--root", rootPath
        ])
        let second = await PDKKitCLI.invoke(arguments: [
            "corpus", "--suite", suitePath, "--root", rootPath
        ])
        #expect(first.exitCode == 0)
        #expect(first.standardError.isEmpty)
        #expect(first.standardOutput == second.standardOutput)
    }

    @Test("inspect-view exposes manifest-bound LEF semantics")
    func inspectViewBindsLEF() async throws {
        let manifestPath = fixtureURL().appending(path: "pdk.json").path
        let result = await PDKKitCLI.invoke(arguments: [
            "inspect-view",
            "--manifest", manifestPath,
            "--asset-id", "cells",
            "--format", "lef"
        ])
        #expect(result.exitCode == 0)
        #expect(result.standardError.isEmpty)
        #expect(result.standardOutput.contains("pdk.standard-view" ) == false)
        #expect(result.standardOutput.contains("\"isValid\":true"))
    }

    @Test("validate retains parser-backed cross-view results")
    func validateRetainsStandardViewResults() async throws {
        let manifestPath = fixtureURL().appending(path: "pdk.json").path
        let result = await PDKKitCLI.invoke(arguments: [
            "validate", "--manifest", manifestPath
        ])
        #expect(result.exitCode == 0)
        let data = try #require(result.standardOutput.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let payload = try #require(object["payload"] as? [String: Any])
        let standardViewResults = try #require(payload["standardViewResults"] as? [[String: Any]])
        #expect(standardViewResults.count == 4)
        #expect(standardViewResults.allSatisfy { ($0["status"] as? String) == "completed" })
        let ruleDeckResults = try #require(payload["ruleDeckResults"] as? [[String: Any]])
        #expect(ruleDeckResults.count == 1)

        let disabled = await PDKKitCLI.invoke(arguments: [
            "validate", "--manifest", manifestPath, "--no-standard-views"
        ])
        #expect(disabled.exitCode == 0)
        let disabledData = try #require(disabled.standardOutput.data(using: .utf8))
        let disabledObject = try #require(JSONSerialization.jsonObject(with: disabledData) as? [String: Any])
        let disabledPayload = try #require(disabledObject["payload"] as? [String: Any])
        let disabledResults = try #require(disabledPayload["standardViewResults"] as? [[String: Any]])
        #expect(disabledResults.isEmpty)

        let ruleDeckDisabled = await PDKKitCLI.invoke(arguments: [
            "validate", "--manifest", manifestPath, "--no-rule-decks"
        ])
        #expect(ruleDeckDisabled.exitCode == 0)
        let ruleDeckDisabledData = try #require(ruleDeckDisabled.standardOutput.data(using: .utf8))
        let ruleDeckDisabledObject = try #require(JSONSerialization.jsonObject(with: ruleDeckDisabledData) as? [String: Any])
        let ruleDeckDisabledPayload = try #require(ruleDeckDisabledObject["payload"] as? [String: Any])
        let ruleDeckDisabledResults = try #require(ruleDeckDisabledPayload["ruleDeckResults"] as? [[String: Any]])
        #expect(ruleDeckDisabledResults.isEmpty)
    }

    @Test("inspect-rule-deck exposes typed layer evidence")
    func inspectRuleDeckExposesLayerEvidence() async throws {
        let result = await PDKKitCLI.invoke(arguments: [
            "inspect-rule-deck",
            "--manifest", fixtureURL().appending(path: "pdk.json").path,
            "--asset-id", "rules"
        ])
        #expect(result.exitCode == 0)
        let data = try #require(result.standardOutput.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["command"] as? String == "inspect-rule-deck")
        #expect(object["status"] as? String == "completed")
        let payload = try #require(object["payload"] as? [String: Any])
        #expect(payload["isValid"] as? Bool == true)
        #expect(payload["observedLayerIDs"] as? [String] == ["active", "metal1"])
        let evidence = try #require(payload["layerEvidence"] as? [[String: Any]])
        #expect(evidence.count == 2)
    }

    @Test("oracle compares immutable standard-view expectations")
    func oracleComparesFixture() async {
        let result = await PDKKitCLI.invoke(arguments: [
            "oracle",
            "--manifest", fixtureURL().appending(path: "pdk.json").path,
            "--oracle", fixtureRootURL().appending(path: "standard-view-oracle.json").path
        ])
        #expect(result.exitCode == 0)
        #expect(result.standardError.isEmpty)
        #expect(result.standardOutput.contains("\"command\":\"oracle\""))
        #expect(result.standardOutput.contains("\"isValid\":true"))
    }

    private func fixtureURL() -> URL {
        PDKTestFixtures.validPDKURL
    }

    private func fixtureRootURL() -> URL {
        PDKTestFixtures.rootURL
    }
}
