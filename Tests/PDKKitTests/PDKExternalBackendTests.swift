import Foundation
import CircuiteFoundation
import Testing
@testable import PDKCore
@testable import PDKStandardViews

@Suite("PDK external backend envelope parity")
struct PDKExternalBackendTests {
    @Test("external standard-view results bind through the manifest contract")
    func externalStandardViewResultsBindThroughManifest() async throws {
        let fixture = fixtureURL()
        let manifestURL = fixture.appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let manifest = try PDKManifestCodec.decode(contentsOf: manifestURL).manifest
        let asset = try #require(manifest.assets.first { $0.assetID == "cells" })
        let resolved = try LocalPDKAssetResolver().resolve(asset, relativeTo: manifestURL)
        let rawRequest = PDKStandardViewInspectionRequest(
            runID: "external-standard-view",
            inputs: [resolved.reference.locator],
            format: .lef,
            assetID: "cells",
            expectedCellNames: ["nmos"],
            projectRootPath: fixture.path
        )
        let localEnvelope = try await LocalPDKStandardViewInspector().execute(rawRequest)
        let resultData = try JSONEncoder().encode(localEnvelope)
        let externalInspector = ExternalPDKStandardViewInspector(
            provider: StaticStandardViewResultProvider(data: resultData)
        )

        let envelope = try await LocalPDKManifestViewInspector(
            standardInspector: externalInspector
        ).execute(
            PDKManifestViewInspectionRequest(
                runID: rawRequest.runID,
                inputs: [pdk.manifest.locator],
                pdk: pdk,
                assetID: "cells",
                format: .lef,
                projectRootPath: fixture.path
            )
        )

        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.inspection?.parserID == localEnvelope.payload.parserID)
        #expect(envelope.payload.binding?.mappingID == "lef-cell-view")
        #expect(envelope.payload.binding?.isValid == true)
    }

    @Test("external standard-view schema and run mismatches are blocked")
    func externalStandardViewContractMismatchesAreBlocked() async throws {
        let request = try standardViewRequest()
        let localEnvelope = try await LocalPDKStandardViewInspector().execute(request)

        var wrongSchema = localEnvelope
        wrongSchema.schemaVersion = 999
        let schemaResult = try await ExternalPDKStandardViewInspector(
            provider: StaticStandardViewResultProvider(data: try JSONEncoder().encode(wrongSchema))
        ).execute(request)
        #expect(schemaResult.status == .blocked)
        #expect(schemaResult.payload.findings.contains {
            $0.code == "pdk.external.standard-view-contract-mismatch"
        })

        var wrongRun = localEnvelope
        wrongRun.runID = "unexpected-run"
        wrongRun.artifacts = [
            try makeArtifactReference(
                artifactID: "external-log",
                path: "external.log",
                kind: .report,
                format: .text,
                sha256: String(repeating: "a", count: 64),
                byteCount: 3
            ).locator,
        ]
        let runResult = try await ExternalPDKStandardViewInspector(
            provider: StaticStandardViewResultProvider(data: try JSONEncoder().encode(wrongRun))
        ).execute(request)
        #expect(runResult.status == .blocked)
        #expect(runResult.payload.findings.contains {
            $0.code == "pdk.external.standard-view-contract-mismatch"
        })
        #expect(runResult.artifacts.map(\.path) == ["external.log"])
    }

    @Test("external standard-view malformed data remains structured")
    func externalStandardViewMalformedDataIsStructured() async throws {
        let request = try standardViewRequest()
        let envelope = try await ExternalPDKStandardViewInspector(
            provider: StaticStandardViewResultProvider(data: Data("not-json".utf8))
        ).execute(request)

        #expect(envelope.status == .failed)
        #expect(envelope.payload.isValid == false)
        #expect(envelope.payload.findings.contains {
            $0.code == "pdk.external.standard-view-contract-mismatch"
        })
        #expect(envelope.payload.limitations.contains {
            $0.contains("typed result boundary")
        })
    }

    @Test("external standard-view source references are bound to requested inputs")
    func externalStandardViewSourceReferenceMismatchIsBlocked() async throws {
        let request = try standardViewRequest()
        var tampered = try await LocalPDKStandardViewInspector().execute(request)
        var inspection = try #require(tampered.payload.inspection)
        inspection.source = try makeArtifactLocator(
            path: "tampered.lef",
            kind: inspection.source.kind,
            format: inspection.source.format,
            role: inspection.source.role
        )
        tampered.payload.inspection = inspection

        let envelope = try await ExternalPDKStandardViewInspector(
            provider: StaticStandardViewResultProvider(data: try JSONEncoder().encode(tampered))
        ).execute(request)

        #expect(envelope.status == .blocked)
        #expect(envelope.payload.findings.contains {
            $0.code == "pdk.external.standard-view-contract-mismatch"
        })
    }

    @Test("external rule-deck results preserve PDK digest binding")
    func externalRuleDeckResultsPreservePDKDigestBinding() async throws {
        let fixture = fixtureURL()
        let manifestURL = fixture.appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let request = PDKRuleDeckInspectionRequest(
            runID: "external-rule-deck",
            inputs: [pdk.manifest.locator],
            pdk: pdk,
            assetID: "rules",
            projectRootPath: fixture.path
        )
        let localEnvelope = try await LocalPDKRuleDeckInspector().execute(request)
        let resultData = try JSONEncoder().encode(localEnvelope)
        let valid = try await ExternalPDKRuleDeckInspector(
            provider: StaticRuleDeckResultProvider(data: resultData)
        ).execute(request)
        #expect(valid.status == .completed, "\(valid.diagnostics)")
        #expect(valid.payload.isValid)
        #expect(valid.payload.pdkDigest == pdk.digest)
        #expect(valid.payload.observedLayerIDs == ["active", "metal1"])
        #expect(valid.payload.sourceArtifact?.digest.algorithm == .sha256)

        var wrongDigest = localEnvelope
        wrongDigest.payload.pdkDigest = "wrong-pdk-digest"
        let blocked = try await ExternalPDKRuleDeckInspector(
            provider: StaticRuleDeckResultProvider(data: try JSONEncoder().encode(wrongDigest))
        ).execute(request)
        #expect(blocked.status == .blocked)
        #expect(blocked.payload.findings.contains {
            $0.code == "pdk.external.rule-deck-contract-mismatch"
        })

        var wrongReference = localEnvelope
        var wrongPayload = wrongReference.payload
        if let reference = wrongPayload.reference {
            wrongPayload.reference = try makeArtifactLocator(
                path: "tampered.deck",
                kind: reference.kind,
                format: reference.format,
                role: reference.role
            )
        }
        wrongReference.payload = wrongPayload
        let referenceBlocked = try await ExternalPDKRuleDeckInspector(
            provider: StaticRuleDeckResultProvider(data: try JSONEncoder().encode(wrongReference))
        ).execute(request)
        #expect(referenceBlocked.status == .blocked)
        #expect(referenceBlocked.payload.findings.contains {
            $0.code == "pdk.external.rule-deck-contract-mismatch"
        })
    }

    @Test("external rule-deck results require canonical artifact identity")
    func externalRuleDeckCanonicalArtifactMismatchIsBlocked() async throws {
        let fixture = fixtureURL()
        let manifestURL = fixture.appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let request = PDKRuleDeckInspectionRequest(
            runID: "external-rule-deck-artifact",
            inputs: [pdk.manifest.locator],
            pdk: pdk,
            assetID: "rules",
            projectRootPath: fixture.path
        )
        var tampered = try await LocalPDKRuleDeckInspector().execute(request)
        tampered.payload.sourceArtifact = nil

        let envelope = try await ExternalPDKRuleDeckInspector(
            provider: StaticRuleDeckResultProvider(data: try JSONEncoder().encode(tampered))
        ).execute(request)

        #expect(envelope.status == .blocked)
        #expect(envelope.payload.findings.contains {
            $0.code == "pdk.external.rule-deck-contract-mismatch"
        })
    }

    @Test("external standard-view results require canonical artifact identity")
    func externalStandardViewCanonicalArtifactMismatchIsBlocked() async throws {
        let request = try standardViewRequest()
        var tampered = try await LocalPDKStandardViewInspector().execute(request)
        var inspection = try #require(tampered.payload.inspection)
        inspection.sourceArtifact = nil
        tampered.payload.inspection = inspection

        let envelope = try await ExternalPDKStandardViewInspector(
            provider: StaticStandardViewResultProvider(data: try JSONEncoder().encode(tampered))
        ).execute(request)

        #expect(envelope.status == .blocked)
        #expect(envelope.payload.findings.contains {
            $0.code == "pdk.external.standard-view-contract-mismatch"
        })
    }

    private func standardViewRequest() throws -> PDKStandardViewInspectionRequest {
        let fixture = fixtureURL()
        let fileURL = fixture.appending(path: "cells.lef")
        let data = try Data(contentsOf: fileURL)
        let reference = try makeArtifactReference(
            artifactID: "cells",
            path: fileURL.path,
            kind: .technology,
            format: .lef,
            sha256: try SHA256ContentDigester().digest(data: data, using: .sha256).hexadecimalValue,
            byteCount: Int64(data.count)
        )
        return PDKStandardViewInspectionRequest(
            runID: "external-standard-view-contract",
            inputs: [reference.locator],
            format: .lef,
            assetID: "cells"
        )
    }

    private func fixtureURL() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/valid-pdk")
    }
}

private struct StaticStandardViewResultProvider: PDKExternalStandardViewResultProviding {
    let data: Data

    func resultData(for request: PDKStandardViewInspectionRequest) async throws -> Data {
        data
    }
}

private struct StaticRuleDeckResultProvider: PDKExternalRuleDeckResultProviding {
    let data: Data

    func resultData(for request: PDKRuleDeckInspectionRequest) async throws -> Data {
        data
    }
}
