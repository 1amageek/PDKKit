import Foundation
import GDSII
import LayoutIR
import OASIS
import Testing
import XcircuitePackage
@testable import PDKCore
@testable import PDKStandardViews

@Suite("PDK standard-view inspection")
struct PDKStandardViewTests {
    @Test("immutable oracle expectation correlates manifest-bound standard views")
    func oracleCorrelationIsReproducible() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let oracleURL = fixtureRootURL().appending(path: "standard-view-oracle.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let oracleData = try Data(contentsOf: oracleURL)
        let oracle = XcircuiteFileReference(
            artifactID: "fixture-standard-view-oracle",
            path: oracleURL.path,
            kind: .technology,
            format: .json,
            sha256: try SHA256PDKDigestor().digest(data: oracleData),
            byteCount: Int64(oracleData.count)
        )

        let envelope = try await LocalPDKOracleComparator().execute(
            PDKOracleRequest(runID: "oracle-correlation", pdk: pdk, oracle: oracle)
        )
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.comparisons.count == 3)
        #expect(envelope.payload.comparisons.allSatisfy { $0.isMatch })
        #expect(envelope.payload.findings.isEmpty)
    }

    @Test("oracle mismatch returns a structured blocker")
    func oracleMismatchIsBlocked() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let oracleURL = fixtureRootURL().appending(path: "standard-view-oracle.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        var expectation = try JSONDecoder().decode(
            PDKOracleExpectation.self,
            from: Data(contentsOf: oracleURL)
        )
        expectation.views[0].expectedLayerNames = ["BROKEN"]
        let data = try JSONEncoder().encode(expectation)
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "pdkkit-oracle-mismatch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Failed to remove oracle mismatch fixture: \(error)")
            }
        }
        let mismatchURL = directory.appending(path: "oracle.json")
        try data.write(to: mismatchURL, options: [.atomic])
        let oracle = XcircuiteFileReference(
            artifactID: "mismatch-oracle",
            path: mismatchURL.path,
            kind: .technology,
            format: .json,
            sha256: try SHA256PDKDigestor().digest(data: data),
            byteCount: Int64(data.count)
        )

        let envelope = try await LocalPDKOracleComparator().execute(
            PDKOracleRequest(runID: "oracle-mismatch", pdk: pdk, oracle: oracle)
        )
        #expect(envelope.status == .blocked)
        #expect(envelope.payload.findings.contains { $0.code == "pdk.oracle.value-mismatch" })
        #expect(envelope.payload.comparisons.contains { !$0.isMatch })
    }

    @Test("manifest-bound LEF inspection returns canonical semantics")
    func lefInspectionBindsManifest() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let request = PDKManifestViewInspectionRequest(
            runID: "lef-inspection",
            inputs: [pdk.manifest],
            pdk: pdk,
            assetID: "cells",
            format: .lef
        )

        let envelope = try await LocalPDKManifestViewInspector().execute(request)
        #expect(envelope.status == .completed, "\(envelope.diagnostics)")
        #expect(envelope.payload.isValid)
        #expect(envelope.payload.inspection?.inspection?.layerNames.contains("M1") == true)
        #expect(envelope.payload.inspection?.inspection?.cellNames.contains("nmos") == true)
        #expect(envelope.payload.binding?.mappingID == "lef-cell-view")
        #expect(envelope.payload.binding?.isValid == true)
        #expect(envelope.payload.binding?.missingCellNames.isEmpty == true)
    }

    @Test("manifest-bound SPICE and Liberty inspection expose device and timing facts")
    func spiceAndLibertyInspectionBindsManifest() async throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        let cases: [(String, PDKStandardViewFormat)] = [
            ("spice-view", .spice),
            ("liberty-view", .liberty),
        ]

        for (assetID, format) in cases {
            let request = PDKManifestViewInspectionRequest(
                runID: "\(format.rawValue)-inspection",
                inputs: [pdk.manifest],
                pdk: pdk,
                assetID: assetID,
                format: format
            )
            let envelope = try await LocalPDKManifestViewInspector().execute(request)
            #expect(envelope.status == .completed, "\(envelope.diagnostics)")
            #expect(envelope.payload.binding?.isValid == true)
            #expect(envelope.payload.binding?.missingCellNames.isEmpty == true)
            #expect(envelope.payload.binding?.missingCornerNames.isEmpty == true)
            if format == .spice {
                #expect(envelope.payload.inspection?.inspection?.modelNames == ["nmos_180n"])
                #expect(envelope.payload.inspection?.inspection?.modelTypes == ["nmos"])
                #expect(envelope.payload.inspection?.inspection?.modelParameterNames == ["level"])
                #expect(envelope.payload.inspection?.inspection?.cornerNames == ["tt"])
            } else {
                #expect(envelope.payload.inspection?.inspection?.cellNames == ["nmos"])
                #expect(envelope.payload.inspection?.inspection?.timingArcCount == 1)
                #expect(envelope.payload.inspection?.inspection?.timingRelatedPinNames == ["G"])
                #expect(envelope.payload.inspection?.inspection?.timingTableValueCount == 1)
                #expect(envelope.payload.inspection?.inspection?.cornerNames == ["tt"])
            }
        }
    }

    @Test("GDSII and OASIS parsers produce the same canonical layer and cell facts")
    func maskViewInspectionIsCanonical() async throws {
        let library = IRLibrary(
            name: "fixture-mask",
            units: IRUnits(dbuPerMicron: 1000),
            cells: [IRCell(
                name: "TOP",
                elements: [.boundary(IRBoundary(
                    layer: 10,
                    datatype: 0,
                    points: [
                        IRPoint(x: 0, y: 0),
                        IRPoint(x: 100, y: 0),
                        IRPoint(x: 100, y: 100),
                        IRPoint(x: 0, y: 100),
                        IRPoint(x: 0, y: 0),
                    ]
                ))]
            )]
        )
        let cases: [(PDKStandardViewFormat, Data, XcircuiteFileFormat)] = [
            (.gdsii, try GDSLibraryWriter.write(library), .gdsii),
            (.oasis, try OASISLibraryWriter.write(library), .oasis),
        ]

        for (format, data, fileFormat) in cases {
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "pdkkit-standard-view-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appending(path: "mask.\(format.rawValue)")
            try data.write(to: fileURL, options: [.atomic])
            defer {
                do {
                    try FileManager.default.removeItem(at: directory)
                } catch {
                    Issue.record("Failed to remove temporary standard-view fixture: \(error)")
                }
            }

            let reference = XcircuiteFileReference(
                artifactID: format.rawValue,
                path: fileURL.path,
                kind: .layout,
                format: fileFormat,
                sha256: try SHA256PDKDigestor().digest(data: data),
                byteCount: Int64(data.count)
            )
            let request = PDKStandardViewInspectionRequest(
                runID: "mask-\(format.rawValue)-inspection",
                inputs: [reference],
                format: format,
                assetID: format.rawValue,
                expectedPhysicalLayerNumbers: [10],
                expectedCellNames: ["TOP"]
            )
            let envelope = try await LocalPDKStandardViewInspector().execute(request)
            #expect(envelope.status == .completed, "\(envelope.diagnostics)")
            #expect(envelope.payload.inspection?.physicalLayerNumbers == [10])
            #expect(envelope.payload.inspection?.cellNames == ["TOP"])
            #expect(envelope.payload.inspection?.elementCount == 1)
        }
    }

    @Test("malformed mask data produces a typed parse failure")
    func malformedMaskDataFailsStructurally() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "pdkkit-malformed-mask-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Failed to remove malformed fixture: \(error)")
            }
        }
        let data = Data("not-gdsii".utf8)
        let fileURL = directory.appending(path: "broken.gdsii")
        try data.write(to: fileURL, options: [.atomic])
        let reference = XcircuiteFileReference(
            artifactID: "broken",
            path: fileURL.path,
            kind: .layout,
            format: .gdsii,
            sha256: try SHA256PDKDigestor().digest(data: data),
            byteCount: Int64(data.count)
        )
        let request = PDKStandardViewInspectionRequest(
            runID: "malformed-mask",
            inputs: [reference],
            format: .gdsii,
            assetID: "broken"
        )

        let envelope = try await LocalPDKStandardViewInspector().execute(request)
        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains { $0.code == "pdk.standard-view.parse-failed" })
    }

    @Test("manifest corner binding blocks an unqualified standard view")
    func missingCornerBindingBlocks() throws {
        let manifestURL = fixtureURL().appending(path: "pdk.json")
        let manifest = try PDKManifestCodec.decode(contentsOf: manifestURL).manifest
        let source = XcircuiteFileReference(
            artifactID: "spice-view",
            path: fixtureURL().appending(path: "models.spice").path,
            kind: .model,
            format: .spice,
            sha256: "fixture",
            byteCount: 1
        )
        let inspection = PDKStandardViewIR(
            format: .spice,
            source: source,
            libraryName: "SPICE",
            modelNames: ["nmos_180n"],
            cornerNames: []
        )

        let report = PDKManifestViewBindingValidator().validate(
            manifest: manifest,
            assetID: "spice-view",
            format: .spice,
            inspection: inspection
        )
        #expect(!report.isValid)
        #expect(report.missingCornerNames == ["tt-1v8-25c"])
        #expect(report.findings.contains { $0.code == "pdk.standard-view.corner-binding-missing" })
    }

    @Test("malformed SPICE and Liberty produce typed parser failures")
    func malformedTextViewsFailStructurally() async throws {
        let cases: [(PDKStandardViewFormat, String, XcircuiteFileFormat)] = [
            (.spice, ".subckt nmos D G\n", .spice),
            (.liberty, "library (broken) {\n  cell (nmos) {\n", .liberty),
        ]
        for (format, text, fileFormat) in cases {
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "pdkkit-malformed-\(format.rawValue)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer {
                do {
                    try FileManager.default.removeItem(at: directory)
                } catch {
                    Issue.record("Failed to remove malformed text fixture: \(error)")
                }
            }
            let data = Data(text.utf8)
            let fileURL = directory.appending(path: "broken.\(format.rawValue)")
            try data.write(to: fileURL, options: [.atomic])
            let reference = XcircuiteFileReference(
                artifactID: "broken-\(format.rawValue)",
                path: fileURL.path,
                kind: .model,
                format: fileFormat,
                sha256: try SHA256PDKDigestor().digest(data: data),
                byteCount: Int64(data.count)
            )
            let request = PDKStandardViewInspectionRequest(
                runID: "malformed-\(format.rawValue)",
                inputs: [reference],
                format: format,
                assetID: format.rawValue
            )
            let envelope = try await LocalPDKStandardViewInspector().execute(request)
            #expect(envelope.status == .failed)
            #expect(envelope.payload.findings.contains { $0.code == "pdk.standard-view.parse-failed" })
        }
    }

    private func fixtureURL() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/valid-pdk")
    }

    private func fixtureRootURL() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures")
    }
}
