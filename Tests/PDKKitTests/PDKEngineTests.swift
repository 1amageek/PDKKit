import Foundation
import CircuiteFoundation
import Testing
@testable import PDKCore
@testable import PDKDiscovery
@testable import PDKStandardViews
@testable import PDKValidation

@Suite("PDK discovery and validation")
struct PDKEngineTests {
    @Test("local validation resolves assets and exports an unqualified scope")
    func validatesFixture() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let request = PDKValidationRequest(
            runID: "validation-fixture",
            inputs: [reference.manifest.locator],
            pdk: reference,
            requiredAssetRoles: [.layerMap, .model, .cell, .ruleDeck]
        )
        let envelope = try await LocalPDKValidator().execute(request)
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.resolvedAssets.count == 7)
        #expect(envelope.payload.qualificationScope?.qualificationState == .unverified)
        #expect(envelope.payload.qualificationScope?.pdkDigest == reference.digest)
        #expect(envelope.payload.capabilityReport?.qualificationState == .unverified)
        #expect(envelope.payload.capabilityReport?.capabilities.contains { $0.capabilityID == "cross-view.mapping" } == true)
        #expect(envelope.payload.standardViewResults.map(\.assetID) == ["cells", "layout", "liberty-view", "spice-view"])
        #expect(envelope.payload.standardViewResults.allSatisfy { $0.status == .completed && $0.payload.isValid })
        #expect(envelope.payload.ruleDeckResults.map(\.assetID) == ["rules"])
        #expect(envelope.payload.ruleDeckResults.first?.observedLayerIDs == ["active", "metal1"])
        #expect(envelope.payload.ruleDeckResults.first?.statementCount == 3)
        #expect(envelope.payload.ruleDeckResults.first?.inspection?.layerEvidence.count == 2)
    }

    @Test("rule-deck inspection exposes manifest-bound layer evidence")
    func ruleDeckInspectorExposesLayerEvidence() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let envelope = try await LocalPDKRuleDeckInspector().execute(
            PDKRuleDeckInspectionRequest(
                runID: "rule-deck-inspection",
                inputs: [reference.manifest.locator],
                pdk: reference,
                assetID: "rules"
            )
        )
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.statementCount == 3)
        #expect(envelope.payload.observedLayerIDs == ["active", "metal1"])
        #expect(envelope.payload.layerEvidence.allSatisfy { !$0.matchedTokens.isEmpty })
        #expect(envelope.artifacts.map(\.path).contains { $0.hasSuffix("/rules.deck") })
    }

    @Test("relative manifest and input references use the explicit project root")
    func validatesRelativeReferences() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let absoluteReference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let relativeManifest = try makeArtifactReference(
            artifactID: absoluteReference.manifest.artifactID,
            path: "pdk.json",
            kind: absoluteReference.manifest.kind,
            format: absoluteReference.manifest.format,
            sha256: absoluteReference.manifest.sha256,
            byteCount: Int64(absoluteReference.manifest.byteCount)
        )
        let relativeReference = PDKReference(
            manifest: relativeManifest,
            processID: absoluteReference.processID,
            version: absoluteReference.version,
            digest: absoluteReference.digest
        )
        let envelope = try await LocalPDKValidator().execute(
            PDKValidationRequest(
                runID: "validation-relative-references",
                inputs: [relativeManifest.locator],
                pdk: relativeReference,
                requiredAssetRoles: [.layerMap, .model],
                projectRootPath: fixtureURL().path
            )
        )
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.resolvedAssets.count == 7)

        #expect(throws: ArtifactLocationError.self) {
            _ = try makeArtifactReference(
                artifactID: relativeManifest.artifactID,
                path: "../pdk.json",
                kind: relativeManifest.kind,
                format: relativeManifest.format,
                sha256: relativeManifest.sha256,
                byteCount: Int64(relativeManifest.byteCount)
            )
        }
    }

    @Test("missing required assets block validation")
    func missingAssetBlocks() async throws {
        let isolatedFixture = try makeIsolatedFixture()
        let manifestURL = isolatedFixture.appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let request = PDKValidationRequest(
            runID: "validation-missing-asset",
            inputs: [reference.manifest.locator],
            pdk: reference
        )
        let missingURL = isolatedFixture.appending(path: "models.spice")
        try FileManager.default.removeItem(at: missingURL)
        defer {
            do {
                try Data(".model nmos_180n nmos level=1\n".utf8).write(to: missingURL)
            } catch {
                Issue.record("Failed to restore fixture asset: \(error)")
            }
        }
        let envelope = try await LocalPDKValidator().execute(request)
        #expect(envelope.status == .blocked)
        #expect(envelope.diagnostics.contains { $0.code.rawValue == "pdk.validation.required-asset-unavailable" })
        #expect(envelope.payload.standardViewResults.contains {
            $0.assetID == "spice-view" && $0.status == .blocked
        })
    }

    @Test("manifest validation blocks unsupported cross-view semantics")
    func standardViewSemanticFailureBlocksValidation() async throws {
        let isolatedFixture = try makeIsolatedFixture()
        defer {
            do {
                try FileManager.default.removeItem(at: isolatedFixture)
            } catch {
                Issue.record("Failed to remove semantic validation fixture: \(error)")
            }
        }
        let manifestURL = isolatedFixture.appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        try Data(".lib tt\n.model nmos_180n nmos level={vto + delta}\n.endl tt\n.end\n".utf8)
            .write(to: isolatedFixture.appending(path: "models.spice"), options: [.atomic])

        let envelope = try await LocalPDKValidator().execute(
            PDKValidationRequest(
                runID: "validation-semantic-block",
                inputs: [reference.manifest.locator],
                pdk: reference,
                requiredAssetRoles: [.model]
            )
        )
        #expect(envelope.status == .blocked, "\(envelope.diagnostics)")
        #expect(envelope.payload.standardViewResults.contains {
            $0.assetID == "spice-view" && $0.status == .blocked
        })
        #expect(envelope.payload.findings.contains {
            $0.code == "pdk.standard-view.spice-parameter-unsupported"
        })
    }

    @Test("manifest validation blocks a rule deck without mapped layer evidence")
    func ruleDeckSemanticFailureBlocksValidation() async throws {
        let isolatedFixture = try makeIsolatedFixture()
        defer {
            do {
                try FileManager.default.removeItem(at: isolatedFixture)
            } catch {
                Issue.record("Failed to remove rule-deck validation fixture: \(error)")
            }
        }
        let manifestURL = isolatedFixture.appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        try Data("RULESET fixture-180nm\n".utf8)
            .write(to: isolatedFixture.appending(path: "rules.deck"), options: [.atomic])

        let envelope = try await LocalPDKValidator().execute(
            PDKValidationRequest(
                runID: "validation-rule-deck-block",
                inputs: [reference.manifest.locator],
                pdk: reference,
                requiredAssetRoles: [.ruleDeck]
            )
        )
        #expect(envelope.status == .blocked, "\(envelope.diagnostics)")
        #expect(envelope.payload.ruleDeckResults.contains {
            $0.assetID == "rules" && $0.status == .blocked
        })
        #expect(envelope.payload.findings.contains {
            $0.code == "pdk.validation.rule-deck-layer-missing"
        })
    }

    @Test("rule-deck comments cannot satisfy mapped layer evidence")
    func ruleDeckCommentsDoNotSatisfyLayerEvidence() async throws {
        let isolatedFixture = try makeIsolatedFixture()
        defer {
            do {
                try FileManager.default.removeItem(at: isolatedFixture)
            } catch {
                Issue.record("Failed to remove comment validation fixture: \(error)")
            }
        }
        let manifestURL = isolatedFixture.appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        try Data("/* ACTIVE M1 */\nRULESET fixture-180nm\n".utf8)
            .write(to: isolatedFixture.appending(path: "rules.deck"), options: [.atomic])

        let envelope = try await LocalPDKRuleDeckInspector().execute(
            PDKRuleDeckInspectionRequest(
                runID: "rule-deck-comment-block",
                inputs: [reference.manifest.locator],
                pdk: reference,
                assetID: "rules"
            )
        )
        #expect(envelope.status == .blocked)
        #expect(envelope.payload.observedLayerIDs.isEmpty)
        #expect(envelope.payload.findings.contains {
            $0.code == "pdk.validation.rule-deck-layer-missing"
        })
    }

    @Test("rule-deck inspection fails on unterminated block comments")
    func ruleDeckUnterminatedCommentFails() async throws {
        let isolatedFixture = try makeIsolatedFixture()
        defer {
            do {
                try FileManager.default.removeItem(at: isolatedFixture)
            } catch {
                Issue.record("Failed to remove unterminated comment fixture: \(error)")
            }
        }
        let manifestURL = isolatedFixture.appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        try Data("RULESET fixture-180nm\nLAYER ACTIVE 1\nLAYER M1 10\n/* unterminated\n".utf8)
            .write(to: isolatedFixture.appending(path: "rules.deck"), options: [.atomic])

        let envelope = try await LocalPDKRuleDeckInspector().execute(
            PDKRuleDeckInspectionRequest(
                runID: "rule-deck-comment-failure",
                inputs: [reference.manifest.locator],
                pdk: reference,
                assetID: "rules"
            )
        )
        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains {
            $0.code == "pdk.validation.rule-deck-comment-unclosed"
        })
    }

    @Test("discovery is deterministic and does not claim qualification")
    func discoveryFindsFixture() async throws {
        let request = PDKDiscoveryRequest(
            runID: "discovery-fixture",
            inputs: [],
            searchRoots: [fixtureURL().path],
            requiredProcessID: "fixture-180nm"
        )
        let envelope = try await LocalPDKDiscoverer().execute(request)
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.candidates.count == 1)
        #expect(envelope.payload.candidates[0].processID == "fixture-180nm")
    }

    @Test("discovery requests require the current complete schema")
    func discoveryRequestRequiresCurrentSchema() throws {
        let request = PDKDiscoveryRequest(
            runID: "discovery-contract",
            inputs: [],
            searchRoots: [fixtureURL().path]
        )
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PDKDiscoveryRequest.self, from: encoded)
        #expect(decoded == request)

        var obsoleteObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        obsoleteObject.removeValue(forKey: "schemaVersion")
        let missingSchemaData = try JSONSerialization.data(withJSONObject: obsoleteObject)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PDKDiscoveryRequest.self, from: missingSchemaData)
        }

        obsoleteObject["schemaVersion"] = 0
        let obsoleteSchemaData = try JSONSerialization.data(withJSONObject: obsoleteObject)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PDKDiscoveryRequest.self, from: obsoleteSchemaData)
        }
    }

    @Test("retained corpus evaluates valid and blocked cases deterministically")
    func corpusEvaluatesExpectedOutcomes() async throws {
        let rootURL = fixtureRootURL()
        let suiteURL = rootURL.appending(path: "pdk-corpus.json")
        let request = PDKCorpusValidationRequest(
            runID: "corpus-fixture",
            suitePath: suiteURL.path,
            rootPath: rootURL.path
        )
        let envelope = try await LocalPDKCorpusValidator().execute(request)
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.caseCount == 3)
        #expect(envelope.payload.passedCaseCount == 3)
        #expect(envelope.payload.caseResults.map(\.caseID) == [
            "invalid-manifest-is-failed",
            "missing-manifest-is-blocked",
            "retained-fixture-is-valid"
        ])
        #expect(envelope.payload.caseResults[0].observedOutcome == .failed)
        #expect(envelope.payload.caseResults[0].observedFindingCodes.contains("pdk.corpus.reference-build-failed"))
        #expect(envelope.payload.caseResults[1].observedOutcome == .blocked)
        #expect(envelope.payload.caseResults[1].observedFindingCodes.contains("pdk.corpus.manifest-missing"))
        let validCase = envelope.payload.caseResults[2]
        #expect(validCase.standardViewResults.count == 3)
        #expect(validCase.standardViewResults.allSatisfy { $0.passed })
        #expect(validCase.standardViewResults.map(\.format) == ["lef", "liberty", "spice"])
        #expect(validCase.ruleDeckResults.count == 1)
        #expect(validCase.ruleDeckResults.first?.passed == true)
    }

    @Test("obsolete corpus schema is rejected")
    func obsoleteCorpusSchemaIsRejected() throws {
        let suiteData = try Data(contentsOf: fixtureRootURL().appending(path: "pdk-corpus.json"))
        var object = try #require(JSONSerialization.jsonObject(with: suiteData) as? [String: Any])
        object["schemaVersion"] = 1
        var cases = try #require(object["cases"] as? [[String: Any]])
        for index in cases.indices {
            cases[index].removeValue(forKey: "ruleDeckChecks")
        }
        object["cases"] = cases
        let obsoleteData = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: PDKCorpusSuiteCodecError.self) {
            try PDKCorpusSuiteCodec().decode(data: obsoleteData)
        }
    }

    @Test("corpus retains a blocked rule-deck result")
    func corpusRetainsBlockedRuleDeckResult() async throws {
        let isolatedFixture = try makeIsolatedFixture()
        defer {
            do {
                try FileManager.default.removeItem(at: isolatedFixture)
            } catch {
                Issue.record("Failed to remove blocked corpus fixture: \(error)")
            }
        }
        try Data("RULESET fixture-180nm\n".utf8)
            .write(to: isolatedFixture.appending(path: "rules.deck"), options: [.atomic])
        let suite = PDKCorpusSuite(
            suiteID: "rule-deck-blocked-suite",
            processID: "fixture-180nm",
            version: "2026.1",
            cases: [PDKCorpusCase(
                caseID: "blocked-rule-deck",
                manifestPath: "pdk.json",
                expectedOutcome: .blocked,
                requiredAssetRoles: [.ruleDeck],
                ruleDeckChecks: [PDKCorpusRuleDeckCheck(
                    assetID: "rules",
                    expectedOutcome: .blocked,
                    expectedFindingCodes: ["pdk.validation.rule-deck-layer-missing"]
                )]
            )]
        )
        let suiteURL = isolatedFixture.appending(path: "suite.json")
        try PDKCorpusSuiteCodec().encode(suite).write(to: suiteURL, options: [.atomic])
        let envelope = try await LocalPDKCorpusValidator().execute(
            PDKCorpusValidationRequest(
                runID: "blocked-rule-deck-corpus",
                suitePath: suiteURL.path,
                rootPath: isolatedFixture.path
            )
        )
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.caseResults.first?.ruleDeckResults.first?.passed == true)
        #expect(envelope.payload.caseResults.first?.ruleDeckResults.first?.observedOutcome == .blocked)
    }

    @Test("qualification evaluator consumes immutable corpus and oracle payload artifacts")
    func qualificationEvaluatorConsumesPayloadArtifacts() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "pdkkit-qualification-evaluator-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Failed to remove qualification evaluator fixture: \(error)")
            }
        }

        let corpusPayload = PDKCorpusValidationPayload(
            suiteID: "fixture-suite",
            processID: pdk.processID,
            version: pdk.version,
            isValid: true,
            caseResults: [PDKCorpusCaseResult(
                caseID: "valid",
                manifestPath: manifestURL.path,
                expectedOutcome: .valid,
                observedOutcome: .valid,
                passed: true,
                expectedFindingCodes: [],
                observedFindingCodes: [],
                missingExpectedFindingCodes: [],
                manifestReference: pdk.manifest
            )]
        )
        let oraclePayload = PDKOracleComparisonPayload(
            isValid: true,
            oracleID: "fixture-oracle",
            pdkDigest: pdk.digest,
            comparisons: [PDKOracleViewComparison(
                assetID: "cells",
                format: .lef,
                isMatch: true
            )]
        )
        let corpusData = try JSONEncoder().encode(corpusPayload)
        let oracleData = try JSONEncoder().encode(oraclePayload)
        let corpusURL = directory.appending(path: "corpus.json")
        let oracleURL = directory.appending(path: "oracle.json")
        try corpusData.write(to: corpusURL, options: [.atomic])
        try oracleData.write(to: oracleURL, options: [.atomic])
        let corpusReference = try makeArtifactReference(
            artifactID: "corpus",
            path: "corpus.json",
            kind: .report,
            format: .json,
            sha256: try SHA256ContentDigester().digest(data: corpusData, using: .sha256).hexadecimalValue,
            byteCount: Int64(corpusData.count)
        )
        let oracleReference = try makeArtifactReference(
            artifactID: "oracle",
            path: "oracle.json",
            kind: .report,
            format: .json,
            sha256: try SHA256ContentDigester().digest(data: oracleData, using: .sha256).hexadecimalValue,
            byteCount: Int64(oracleData.count)
        )

        let envelope = try await LocalPDKQualificationEvaluator().execute(
            PDKQualificationRequest(
                runID: "qualification-evaluator",
                pdk: pdk,
                corpusReport: corpusReference,
                oracleReport: oracleReference,
                projectRootPath: directory.path
            )
        )
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.state == .oracleCorrelated)
    }

    @Test("requests and payloads round-trip with the shared JSON contract")
    func requestPayloadRoundTrip() throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let request = PDKValidationRequest(
            runID: "round-trip",
            inputs: [reference.manifest.locator],
            pdk: reference,
            requiredAssetRoles: [.model],
            validateCrossViews: false
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let requestData = try encoder.encode(request)
        let decodedRequest = try JSONDecoder().decode(PDKValidationRequest.self, from: requestData)
        #expect(decodedRequest == request)
        #expect(request.schemaVersion == PDKValidationRequest.currentSchemaVersion)

        var obsoleteObject = try #require(JSONSerialization.jsonObject(with: requestData) as? [String: Any])
        obsoleteObject["schemaVersion"] = 1
        obsoleteObject.removeValue(forKey: "validateStandardViews")
        obsoleteObject.removeValue(forKey: "validateRuleDecks")
        let obsoleteData = try JSONSerialization.data(withJSONObject: obsoleteObject)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PDKValidationRequest.self, from: obsoleteData)
        }

        obsoleteObject.removeValue(forKey: "schemaVersion")
        let missingSchemaData = try JSONSerialization.data(withJSONObject: obsoleteObject)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PDKValidationRequest.self, from: missingSchemaData)
        }

        let payload = PDKValidationPayload(isValid: false, missingRequirements: ["models"])
        let payloadData = try encoder.encode(payload)
        let decodedPayload = try JSONDecoder().decode(PDKValidationPayload.self, from: payloadData)
        #expect(decodedPayload == payload)
    }

    private func fixtureURL() -> URL {
        fixtureRootURL().appending(path: "valid-pdk")
    }

    private func fixtureRootURL() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures")
    }

    private func makeIsolatedFixture() throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appending(path: "pdkkit-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: fixtureURL(), to: destination)
        return destination
    }
}
