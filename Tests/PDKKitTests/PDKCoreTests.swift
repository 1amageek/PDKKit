import Foundation
import Testing
import CircuiteFoundation
@testable import PDKCore

@Suite("PDKCore implementation")
struct PDKCoreTests {
    @Test("decodes retained fixture and keeps the manifest schema current")
    func retainedFixtureDecodes() throws {
        let manifest = try PDKManifestCodec.decode(contentsOf: fixtureURL().appending(path: "pdk.json"))
        #expect(manifest.schemaVersion == PDKManifest.currentSchemaVersion)
        #expect(manifest.processID == "fixture-180nm")
        #expect(manifest.validate().isValid)
    }

    @Test("rejects manifests without the current schema version")
    func manifestWithoutSchemaVersionIsRejected() {
        let data = Data(
            "{\"processID\":\"fixture-65nm\",\"version\":\"0.9\",\"assets\":[],\"layers\":[],\"devices\":[],\"corners\":[],\"crossViewMappings\":[],\"metadata\":{}}".utf8
        )
        #expect(throws: PDKManifestError.self) {
            try PDKManifestCodec.decode(data: data)
        }
    }

    @Test("rejects obsolete manifest field names")
    func obsoleteManifestFieldNamesAreRejected() {
        let data = Data(
            "{\"schemaVersion\":1,\"process\":\"fixture-45nm\",\"pdkVersion\":\"0.1\",\"files\":[],\"layers\":[],\"devices\":[],\"corners\":[],\"crossViewMappings\":[],\"metadata\":{}}".utf8
        )
        #expect(throws: PDKManifestError.self) {
            try PDKManifestCodec.decode(data: data)
        }
    }

    @Test("rejects manifests missing canonical collection fields")
    func manifestMissingCanonicalCollectionsIsRejected() {
        let data = Data(
            "{\"schemaVersion\":1,\"processID\":\"fixture-45nm\",\"version\":\"0.1\"}".utf8
        )
        #expect(throws: PDKManifestError.self) {
            try PDKManifestCodec.decode(data: data)
        }
    }

    @Test("computes a stable lowercase SHA-256 digest")
    func digestIsStable() throws {
        let digest = try SHA256ContentDigester().digest(data: Data("PDKKit".utf8), using: .sha256).hexadecimalValue
        #expect(digest == "951825a4fd0dac93935d2498d902f7c2d19ab55ef8344bba73366aa2a9cfbe2c")
    }

    @Test("resolved assets expose canonical Foundation artifact identity")
    func resolvedAssetProjectsToFoundation() throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let manifest = try PDKManifestCodec.decode(contentsOf: manifestURL)
        let asset = try #require(manifest.assets.first(where: { $0.assetID == "models" }))

        let resolved = try LocalPDKAssetResolver().resolve(asset, relativeTo: manifestURL)
        let foundationReference = try resolved.artifactReference()

        #expect(foundationReference.id.rawValue == "models")
        #expect(foundationReference.digest.algorithm == .sha256)
        #expect(foundationReference.digest.hexadecimalValue == resolved.computedSHA256)
        #expect(foundationReference.byteCount == UInt64(resolved.computedByteCount))
        #expect(foundationReference.locator.location.storage == .absoluteFileURL)
    }

    @Test("asset resolution rejects symlink escapes through Foundation containment")
    func assetResolverRejectsSymlinkEscape() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "pdkkit-foundation-root-\(UUID().uuidString)")
        let outside = root.deletingLastPathComponent()
            .appending(path: "pdkkit-foundation-outside-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
                try FileManager.default.removeItem(at: outside)
            } catch {
                Issue.record("Failed to clean up symlink fixture: \(error)")
            }
        }

        let outsideFile = outside.appending(path: "payload.bin")
        try Data("outside".utf8).write(to: outsideFile)
        let symlink = root.appending(path: "linked", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)

        let asset = PDKAssetReference(
            assetID: "escaped",
            role: .other,
            path: "linked/payload.bin",
            kind: .other,
            format: .raw
        )
        let manifestURL = root.appending(path: "pdk.json")

        do {
            _ = try LocalPDKAssetResolver().resolve(asset, relativeTo: manifestURL)
            Issue.record("Symlink escape was not rejected")
        } catch let error as PDKAssetResolutionError {
            #expect(error == .outsideManifestRoot(assetID: "escaped", path: outsideFile.path))
        }
    }

    @Test("PDK reference requires its manifest digest to match")
    func pdkReferenceValidatesManifestIdentity() throws {
        let manifestDigest = String(repeating: "a", count: 64)
        let pdkDigest = String(repeating: "b", count: 64)
        let manifest = try makeArtifactReference(
            artifactID: "pdk-manifest",
            path: "/tmp/pdk.json",
            kind: .technology,
            format: .json,
            sha256: manifestDigest,
            byteCount: 16
        )
        let reference = PDKReference(
            manifest: manifest,
            processID: "fixture-180nm",
            version: "2026.1",
            digest: pdkDigest
        )

        #expect(throws: PDKReferenceError.self) {
            try reference.validate()
        }
    }

    @Test("manifest references project to a typed Foundation artifact")
    func manifestReferenceProjectsToFoundation() throws {
        let reference = try PDKManifestReferenceBuilder().makeReference(
            for: fixtureURL().appending(path: "pdk.json")
        )
        let foundationReference = try reference.validatedManifest()

        #expect(foundationReference.id.rawValue == "pdk-manifest")
        #expect(foundationReference.locator.kind.rawValue == "pdk.technology")
        #expect(foundationReference.locator.format == .json)
        #expect(foundationReference.digest.hexadecimalValue == reference.digest)
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

    @Test("artifact references resolve relative to an explicit project root")
    func artifactReferencesUseProjectRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "pdkkit-artifact-root-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                Issue.record("Failed to remove artifact root fixture: \(error)")
            }
        }

        let reference = try makeArtifactReference(
            artifactID: "report",
            path: "reports/result.json",
            kind: .report,
            format: .json
        )
        let resolved = try PDKArtifactURLResolver().resolve(
            reference.locator,
            baseDirectoryPath: root.path
        )
        #expect(resolved.path == root.appending(path: "reports/result.json").path)
        #expect(throws: ArtifactLocationError.self) {
            try PDKArtifactURLResolver().resolve(
                try makeArtifactReference(
                    path: "../outside.json",
                    kind: .report,
                    format: .json
                ).locator,
                baseDirectoryPath: root.path
            )
        }
    }

    private func fixtureURL() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/valid-pdk")
    }
}
