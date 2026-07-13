import Foundation
import Testing
import XcircuitePackage
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
            inputs: [reference.manifest],
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
    }

    @Test("relative manifest and input references use the explicit project root")
    func validatesRelativeReferences() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let absoluteReference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let relativeManifest = XcircuiteFileReference(
            artifactID: absoluteReference.manifest.artifactID,
            path: "pdk.json",
            kind: absoluteReference.manifest.kind,
            format: absoluteReference.manifest.format,
            sha256: absoluteReference.manifest.sha256,
            byteCount: absoluteReference.manifest.byteCount
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
                inputs: [relativeManifest],
                pdk: relativeReference,
                requiredAssetRoles: [.layerMap, .model],
                projectRootPath: fixtureURL().path
            )
        )
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.resolvedAssets.count == 7)

        let traversalManifest = XcircuiteFileReference(
            artifactID: relativeManifest.artifactID,
            path: "../pdk.json",
            kind: relativeManifest.kind,
            format: relativeManifest.format,
            sha256: relativeManifest.sha256,
            byteCount: relativeManifest.byteCount
        )
        let blocked = try await LocalPDKValidator().execute(
            PDKValidationRequest(
                runID: "validation-relative-traversal",
                inputs: [traversalManifest],
                pdk: PDKReference(
                    manifest: traversalManifest,
                    processID: absoluteReference.processID,
                    version: absoluteReference.version,
                    digest: absoluteReference.digest
                ),
                projectRootPath: fixtureURL().path
            )
        )
        #expect(blocked.status == .blocked)
        #expect(blocked.payload.findings.contains { $0.code == "pdk.validation.manifest-path-invalid" })
    }

    @Test("missing required assets block validation")
    func missingAssetBlocks() async throws {
        let isolatedFixture = try makeIsolatedFixture()
        let manifestURL = isolatedFixture.appending(path: "pdk.json")
        let reference = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let request = PDKValidationRequest(
            runID: "validation-missing-asset",
            inputs: [reference.manifest],
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
        #expect(envelope.diagnostics.contains { $0.code == "pdk.validation.required-asset-unavailable" })
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
        let corpusReference = XcircuiteFileReference(
            artifactID: "corpus",
            path: "corpus.json",
            kind: .report,
            format: .json,
            sha256: try SHA256PDKDigestor().digest(data: corpusData),
            byteCount: Int64(corpusData.count)
        )
        let oracleReference = XcircuiteFileReference(
            artifactID: "oracle",
            path: "oracle.json",
            kind: .report,
            format: .json,
            sha256: try SHA256PDKDigestor().digest(data: oracleData),
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
            inputs: [reference.manifest],
            pdk: reference,
            requiredAssetRoles: [.model],
            validateCrossViews: false
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let requestData = try encoder.encode(request)
        let decodedRequest = try JSONDecoder().decode(PDKValidationRequest.self, from: requestData)
        #expect(decodedRequest == request)

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
