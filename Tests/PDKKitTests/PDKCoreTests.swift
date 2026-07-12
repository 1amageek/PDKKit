import Foundation
import Testing
@testable import PDKCore

@Suite("PDKCore implementation")
struct PDKCoreTests {
    @Test("decodes retained fixture and keeps the manifest schema current")
    func retainedFixtureDecodes() throws {
        let migration = try PDKManifestCodec.decode(contentsOf: fixtureURL().appending(path: "pdk.json"))
        #expect(migration.sourceSchemaVersion == 1)
        #expect(migration.wasMigrated == false)
        #expect(migration.manifest.processID == "fixture-180nm")
        #expect(migration.manifest.validate().isValid)
    }

    @Test("migrates the legacy process and file keys")
    func legacyManifestMigrates() throws {
        let data = Data(
            "{\"process\":\"legacy-65nm\",\"pdkVersion\":\"0.9\",\"files\":[]}".utf8
        )
        let migration = try PDKManifestCodec.decode(data: data)
        #expect(migration.sourceSchemaVersion == 0)
        #expect(migration.wasMigrated)
        #expect(migration.manifest.schemaVersion == PDKManifest.currentSchemaVersion)
        #expect(migration.manifest.processID == "legacy-65nm")
        #expect(migration.manifest.version == "0.9")
    }

    @Test("migrates a legacy list of file paths")
    func legacyFilePathsMigrate() throws {
        let data = Data(
            "{\"process\":\"legacy-45nm\",\"pdkVersion\":\"0.1\",\"files\":[\"models.spice\"]}".utf8
        )
        let migration = try PDKManifestCodec.decode(data: data)
        #expect(migration.manifest.assets.count == 1)
        #expect(migration.manifest.assets[0].path == "models.spice")
        #expect(migration.manifest.assets[0].format == .unknown)
    }

    @Test("computes a stable lowercase SHA-256 digest")
    func digestIsStable() throws {
        let digest = try SHA256PDKDigestor().digest(data: Data("PDKKit".utf8))
        #expect(digest == "951825a4fd0dac93935d2498d902f7c2d19ab55ef8344bba73366aa2a9cfbe2c")
    }

    @Test("corpus suite validation blocks path traversal")
    func corpusSuiteBlocksUnsafePath() {
        let suite = PDKCorpusSuite(
            suiteID: "unsafe",
            processID: "fixture-180nm",
            version: "2026.1",
            cases: [PDKCorpusCase(
                caseID: "unsafe-case",
                manifestPath: "../pdk.json",
                expectedOutcome: .blocked
            )]
        )
        let report = PDKCorpusSuiteValidator().validate(suite)
        #expect(!report.isValid)
        #expect(report.findings.contains { $0.code == "pdk.corpus.unsafe-manifest-path" })
    }

    private func fixtureURL() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/valid-pdk")
    }
}
