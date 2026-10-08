import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import PDKCore
import PDKStandardViews
import PDKValidation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PDKIdentityCompositionTests {
    @Test(arguments: ["digest", "size"])
    func manifestDeclarationRejectsChangedView(check: String) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let url = fixture.root.appending(path: "pdk.json")
        var manifest = try PDKManifestCodec.decode(contentsOf: url)
        let index = try #require(manifest.assets.firstIndex { $0.assetID == "cells" })
        let bytes = try Data(contentsOf: fixture.root.appending(path: "cells.lef"))
        if check == "digest" {
            manifest.assets[index].sha256 = try SHA256ContentDigester().digest(data: bytes, using: .sha256).hexadecimalValue
            try Self.replaceCells(in: fixture.root)
        } else {
            manifest.assets[index].byteCount = Int64(bytes.count + 1)
        }
        try PDKManifestCodec.encode(manifest).write(to: url)
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: url)
        var request = fixture.viewRequest()
        request.pdk = pdk
        let result = try await LocalPDKManifestViewInspector().execute(request)
        #expect(result.status == .blocked)
        #expect(!result.payload.isValid)
        #expect(result.payload.binding == nil)
        #expect(result.payload.inspection == nil)
    }

    @Test(arguments: [false, true], ["cells", "rules"])
    func validationRejectsReplacementAfterInitialResolution(locked: Bool, assetID: String) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let manifestURL = fixture.root.appending(path: "pdk.json")
        if locked {
            var manifest = try PDKManifestCodec.decode(contentsOf: manifestURL)
            for index in manifest.assets.indices {
                let bytes = try Data(contentsOf: fixture.root.appending(path: manifest.assets[index].path))
                manifest.assets[index].sha256 = try SHA256ContentDigester().digest(data: bytes, using: .sha256).hexadecimalValue
                manifest.assets[index].byteCount = Int64(bytes.count)
            }
            try PDKManifestCodec.encode(manifest).write(to: manifestURL)
        }
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let result = try await LocalPDKValidator(assetResolver: ReplacingResolver(assetID: assetID)).execute(
            PDKValidationRequest(runID: "identity-composition", inputs: [], pdk: pdk, requireAssetIdentity: locked)
        )
        #expect(result.status == .blocked)
        #expect(!result.payload.isValid)
        if assetID == "cells" {
            #expect(result.payload.standardViewResults.first { $0.assetID == assetID }?.status == .blocked)
        } else {
            #expect(result.payload.ruleDeckResults.first { $0.assetID == assetID }?.status == .blocked)
        }
    }

    @Test
    func oracleFailureSurvivesLaterBlockedView() async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        try "MACRO nmos\n SIZE wrong BY 1 ;\nEND nmos\n".write(to: fixture.root.appending(path: "cells.lef"), atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: fixture.root.appending(path: "timing.lib"))
        let expectation = PDKOracleExpectation(
            oracleID: "mixed-status", processID: fixture.pdk.processID, version: fixture.pdk.version,
            pdkDigest: fixture.pdk.digest, views: [
                PDKOracleViewExpectation(assetID: "cells", format: .lef, expectedCellNames: ["nmos"]),
                PDKOracleViewExpectation(assetID: "liberty-view", format: .liberty, expectedCellNames: ["nmos"])
            ]
        )
        let data = try JSONEncoder().encode(expectation)
        let url = fixture.root.appending(path: "oracle.json")
        try data.write(to: url)
        let artifact = try makeArtifactBinding(path: url.path, kind: .technology, format: .json,
            sha256: SHA256ContentDigester().digest(data: data, using: .sha256).hexadecimalValue, byteCount: Int64(data.count))
        let result = try await LocalPDKOracleComparator().execute(PDKOracleRequest(
            runID: "mixed-status", pdk: fixture.pdk, oracle: artifact.reference, oracleLocator: artifact.locator
        ))
        #expect(result.status == .failed)
        #expect(result.payload.findings.contains { $0.code == "pdk.standard-view.parse-failed" })
        #expect(result.payload.findings.contains { $0.code == "pdk.standard-view.asset-unavailable" })
    }

    @Test(arguments: [false, true])
    func validationCancellationStopsFurtherChecks(ruleStage: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let views = CancellingViews()
        let rules = CancellingRules()
        let validator = LocalPDKValidator(standardViewInspector: views, ruleDeckInspector: rules)
        let result = try await validator.execute(PDKValidationRequest(
            runID: "cancel-validation", inputs: [], pdk: fixture.pdk, validateStandardViews: !ruleStage
        ))
        #expect(result.status == .cancelled)
        #expect(!result.payload.isValid)
        #expect(await views.calls == (ruleStage ? 0 : 1))
        #expect(await rules.calls == (ruleStage ? 1 : 0))
        #expect(!result.payload.findings.contains { $0.severity == .error })
    }

    @Test(arguments: [false, true], [false, true])
    func injectedCompletedEvidenceMustRetainInitialIdentity(ruleStage: Bool, removeIdentity: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let result = try await LocalPDKValidator(
            standardViewInspector: SubstitutingViews(removeIdentity: removeIdentity),
            ruleDeckInspector: SubstitutingRules(removeIdentity: removeIdentity)
        ).execute(PDKValidationRequest(
            runID: "substitute-completed", inputs: [], pdk: fixture.pdk,
            validateStandardViews: !ruleStage, validateRuleDecks: ruleStage
        ))
        #expect(result.status == .blocked)
        #expect(result.payload.findings.contains { $0.code == "pdk.validation.source-artifact-mismatch" })
    }

    @Test
    func expectedReferenceSurvivesSerializationAndRejectsCurrentReplacement() async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let manifest = try PDKManifestCodec.decode(contentsOf: fixture.root.appending(path: "pdk.json"))
        let asset = try #require(manifest.assets.first { $0.assetID == "cells" })
        let resolved = try LocalPDKAssetResolver().resolve(asset, relativeTo: fixture.root.appending(path: "pdk.json"))
        let request = PDKStandardViewInspectionRequest(
            runID: "pinned-source", inputs: [resolved.locator], format: .lef, assetID: "cells",
            expectedSourceArtifact: resolved.reference
        )
        let decoded = try JSONDecoder().decode(PDKStandardViewInspectionRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded.expectedSourceArtifact == resolved.reference)
        let good = try await LocalPDKStandardViewInspector().execute(decoded)
        #expect(good.status == .completed)
        #expect(good.payload.inspection?.sourceArtifact == resolved.reference)
        var ruleRequest = fixture.ruleRequest()
        ruleRequest.expectedSourceArtifact = resolved.reference
        let decodedRule = try JSONDecoder().decode(PDKRuleDeckInspectionRequest.self, from: JSONEncoder().encode(ruleRequest))
        #expect(decodedRule.expectedSourceArtifact == resolved.reference)
        try Self.replaceCells(in: fixture.root)
        let blocked = try await LocalPDKStandardViewInspector().execute(decoded)
        #expect(blocked.status == .blocked)
        #expect(blocked.payload.inspection == nil)
        var currentRequest = request
        currentRequest.expectedSourceArtifact = nil
        let current = try await LocalPDKStandardViewInspector().execute(currentRequest)
        let external = try await ExternalPDKStandardViewInspector(
            provider: EncodedViewProvider(data: JSONEncoder().encode(current))
        ).execute(decoded)
        #expect(external.status == .blocked)
    }

    @Test(arguments: [false, true])
    func externalRuleRejectsUpstreamAndDeclaredIdentityMismatch(declared: Bool) async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let manifestURL = fixture.root.appending(path: "pdk.json")
        var manifest = try PDKManifestCodec.decode(contentsOf: manifestURL)
        let index = try #require(manifest.assets.firstIndex { $0.assetID == "rules" })
        let resolved = try LocalPDKAssetResolver().resolve(manifest.assets[index], relativeTo: manifestURL)
        var request = fixture.ruleRequest()
        request.expectedSourceArtifact = resolved.reference
        let local = try await LocalPDKRuleDeckInspector().execute(request)
        if declared {
            manifest.assets[index].sha256 = String(repeating: "0", count: 64)
            try PDKManifestCodec.encode(manifest).write(to: manifestURL)
            request.pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
            request.expectedSourceArtifact = nil
            var response = local
            response.payload.pdkDigest = request.pdk.digest
            let result = try await ExternalPDKRuleDeckInspector(
                provider: BoundRuleResultProvider(data: JSONEncoder().encode(response))
            ).execute(request)
            #expect(result.status == .blocked)
        } else {
            try "WIDTH M1 0.3\nWIDTH ACTIVE 0.2\n".write(to: URL(filePath: resolved.path), atomically: true, encoding: .utf8)
            var unpinned = request
            unpinned.expectedSourceArtifact = nil
            let substituted = try await LocalPDKRuleDeckInspector().execute(unpinned)
            #expect(substituted.status == .completed)
            let result = try await ExternalPDKRuleDeckInspector(
                provider: BoundRuleResultProvider(data: JSONEncoder().encode(substituted))
            ).execute(request)
            #expect(result.status == .blocked)
        }
    }

    @Test
    func externalProvidersPreserveCancellation() async throws {
        let fixture = try BoundCaptureFixture()
        defer { fixture.cleanup() }
        let request = PDKStandardViewInspectionRequest(
            runID: "cancel-provider", inputs: [], format: .lef, assetID: "cells"
        )
        let view = try await ExternalPDKStandardViewInspector(provider: CancellingProvider()).execute(request)
        let rule = try await ExternalPDKRuleDeckInspector(provider: CancellingProvider()).execute(fixture.ruleRequest())
        #expect(view.status == .cancelled)
        #expect(rule.status == .cancelled)
        #expect(!view.payload.isValid)
        #expect(!rule.payload.isValid)
    }

    private struct SubstitutingViews: PDKManifestViewInspecting {
        let removeIdentity: Bool
        func execute(_ request: PDKManifestViewInspectionRequest) async throws -> PDKManifestViewInspectionResult {
            var result = try await LocalPDKManifestViewInspector().execute(request)
            var payload = try #require(result.payload.inspection)
            var inspection = try #require(payload.inspection)
            inspection.sourceArtifact = try PDKIdentityCompositionTests.substitute(
                #require(inspection.sourceArtifact), removeIdentity: removeIdentity
            )
            payload.inspection = inspection
            result.payload.inspection = payload
            return result
        }
    }

    private struct SubstitutingRules: PDKRuleDeckInspecting {
        let removeIdentity: Bool
        func execute(_ request: PDKRuleDeckInspectionRequest) async throws -> PDKRuleDeckInspectionResult {
            var result = try await LocalPDKRuleDeckInspector().execute(request)
            result.payload.sourceArtifact = try PDKIdentityCompositionTests.substitute(
                #require(result.payload.sourceArtifact), removeIdentity: removeIdentity
            )
            return result
        }
    }

    private struct EncodedViewProvider: PDKExternalStandardViewResultProviding {
        let data: Data
        func resultData(for request: PDKStandardViewInspectionRequest) async throws -> Data { data }
    }

    private struct CancellingProvider: PDKExternalStandardViewResultProviding, PDKExternalRuleDeckResultProviding {
        func resultData(for request: PDKStandardViewInspectionRequest) async throws -> Data { throw CancellationError() }
        func resultData(for request: PDKRuleDeckInspectionRequest) async throws -> Data { throw CancellationError() }
    }

    private static func substitute(_ reference: ArtifactReference, removeIdentity: Bool) throws -> ArtifactReference? {
        if removeIdentity { return nil }
        return try ArtifactReference(
            digest: reference.digest, byteCount: reference.byteCount,
            descriptor: ArtifactDescriptor(role: .output, kind: reference.kind, format: reference.format)
        )
    }

    private struct ReplacingResolver: PDKAssetResolving {
        let assetID: String
        func resolve(_ asset: PDKAssetReference, relativeTo manifestURL: URL) throws -> PDKResolvedAsset {
            let resolved = try LocalPDKAssetResolver().resolve(asset, relativeTo: manifestURL)
            if asset.assetID == assetID {
                if assetID == "cells" {
                    try PDKIdentityCompositionTests.replaceCells(in: manifestURL.deletingLastPathComponent())
                } else {
                    try "WIDTH M1 0.3\nWIDTH ACTIVE 0.2\n".write(to: URL(filePath: resolved.path), atomically: true, encoding: .utf8)
                }
            }
            return resolved
        }
    }

    private actor CancellingViews: PDKManifestViewInspecting {
        var calls = 0
        func execute(_ request: PDKManifestViewInspectionRequest) async throws -> PDKManifestViewInspectionResult {
            calls += 1
            throw CancellationError()
        }
    }

    private actor CancellingRules: PDKRuleDeckInspecting {
        var calls = 0
        func execute(_ request: PDKRuleDeckInspectionRequest) async throws -> PDKRuleDeckInspectionResult {
            calls += 1
            throw CancellationError()
        }
    }

    private static func replaceCells(in root: URL) throws {
        let url = root.appending(path: "cells.lef")
        let original = try String(contentsOf: url, encoding: .utf8)
        try original.replacingOccurrences(of: "PITCH 0.2", with: "PITCH 0.3").write(to: url, atomically: true, encoding: .utf8)
    }
}
