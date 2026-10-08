import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import PDKCore
import PDKStandardViews
import Testing

struct BoundCaptureFixture {
    let root: URL
    let pdk: PDKReference

    init() async throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.copyItem(at: PDKTestFixtures.validPDKURL, to: root)
        pdk = try await loadPDKReference(for: root.appending(path: "pdk.json"))
    }

    func cleanup() {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record("Fixture cleanup failed: \(error)") }
    }

    func viewRequest() -> PDKManifestViewInspectionRequest {
        PDKManifestViewInspectionRequest(
            runID: "bound-view-capture", inputs: [pdk.manifestLocator],
            pdk: pdk, assetID: "cells", format: .lef, projectRootPath: root.path
        )
    }

    func ruleRequest() -> PDKRuleDeckInspectionRequest {
        PDKRuleDeckInspectionRequest(
            runID: "bound-rule-capture", inputs: [pdk.manifestLocator],
            pdk: pdk, assetID: "rules", projectRootPath: root.path
        )
    }

    func oracleRequest() throws -> PDKOracleRequest {
        let data = try JSONEncoder().encode(PDKOracleExpectation(
            oracleID: "captured-oracle", processID: pdk.processID, version: pdk.version,
            pdkDigest: pdk.digest,
            views: [PDKOracleViewExpectation(assetID: "cells", format: .lef, expectedCellNames: ["nmos"])]
        ))
        let url = root.appending(path: "oracle.json")
        try data.write(to: url)
        let artifact = try makeArtifactBinding(
            path: url.path, kind: .technology, format: .json,
            sha256: SHA256ContentDigester().digest(data: data, using: .sha256).hexadecimalValue,
            byteCount: Int64(data.count)
        )
        return PDKOracleRequest(
            runID: "bound-oracle-capture", pdk: pdk, oracle: artifact.reference,
            oracleLocator: artifact.locator, projectRootPath: root.path
        )
    }
}
