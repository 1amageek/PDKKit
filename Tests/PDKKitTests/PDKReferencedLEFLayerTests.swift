import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import PDKCore
import PDKStandardViews
import Testing

@Suite("Referenced LEF layer inventory", .timeLimit(.minutes(1)))
struct PDKReferencedLEFLayerTests {
    @Test func macroOnlyPortLayerBindsSourceAsset() async throws {
        let source = """
        VERSION 5.8 ;
        UNITS DATABASE MICRONS 1000 ; END UNITS
        MACRO INV CLASS CORE ; SIZE 0.4 BY 1.0 ;
          PIN in DIRECTION INPUT ; USE SIGNAL ;
            PORT LAYER M1 ; RECT 0.0 0.0 0.1 0.1 ; END
          END in
        END INV
        END LIBRARY
        """
        try await inspect(source) { result, binding in
            try #require(result.status == .completed, "\(result.diagnostics)")
            let observed = try #require(result.payload.inspection)
            #expect(observed.layerNames == ["M1"])
            #expect(try #require(observed.lefDocument).layers.isEmpty)
            #expect(observed.sourceArtifact == binding.reference)
            let report = PDKManifestViewBindingValidator().validate(manifest: manifest(layers: ["M1"]),
                assetID: "cells", format: .lef, inspection: observed)
            #expect(report.isValid, "\(report.findings)")
            #expect(report.missingLayerNames.isEmpty && report.observedLayerNames == ["M1"])
        }
    }

    @Test func layerInventoryUnionsSourceReferencesWithoutDeclaringRules() async throws {
        let source = """
        VERSION 5.8 ;
        UNITS DATABASE MICRONS 1000 ; END UNITS
        LAYER DECLARED TYPE ROUTING ; DIRECTION HORIZONTAL ; WIDTH 0.1 ; END DECLARED
        VIA VIA12 DEFAULT
          LAYER M1 ; RECT -0.1 -0.1 0.1 0.1 ;
          LAYER V1 ; RECT -0.05 -0.05 0.05 0.05 ;
          LAYER M2 ; RECT -0.1 -0.1 0.1 0.1 ;
        END VIA12
        MACRO INV CLASS CORE ; SIZE 0.4 BY 1.0 ;
          PIN in DIRECTION INPUT ; USE SIGNAL ;
            PORT LAYER M1 ; RECT 0.0 0.0 0.1 0.1 ; VIA 0.05 0.05 VIA12 ; END
          END in
          OBS LAYER OBS_ONLY ; RECT 0.2 0.1 0.3 0.9 ; END
        END INV
        END LIBRARY
        """
        let layers = ["DECLARED", "M1", "M2", "OBS_ONLY", "V1"]
        try await inspect(source, expectedLayers: layers) { result, binding in
            try #require(result.status == .completed, "\(result.diagnostics)")
            let observed = try #require(result.payload.inspection)
            #expect(observed.layerNames == layers)
            let document = try #require(observed.lefDocument)
            #expect(document.layers.map(\.name) == ["DECLARED"])
            #expect(document.layers.first?.width == 0.1)
            #expect(document.macros[0].pins[0].ports[0].layerName == "M1")
            #expect(document.macros[0].pins[0].ports[0].vias[0].viaName == "VIA12")
            #expect(document.macros[0].obs[0].layerName == "OBS_ONLY")
            #expect(document.vias[0].layers.map(\.layerName) == ["M1", "V1", "M2"])
            #expect(observed.sourceArtifact == binding.reference)
            #expect(try JSONDecoder().decode(PDKStandardViewIR.self,
                from: JSONEncoder().encode(observed)) == observed)
            let report = PDKManifestViewBindingValidator().validate(manifest: manifest(layers: layers),
                assetID: "cells", format: .lef, inspection: observed)
            #expect(report.isValid, "\(report.findings)")
        }
    }

    @Test func absentAndExternalViaOnlyLayersRemainUnobserved() async throws {
        let source = """
        VERSION 5.8 ;
        UNITS DATABASE MICRONS 1000 ; END UNITS
        MACRO INV CLASS CORE ; SIZE 0.4 BY 1.0 ;
          PIN in DIRECTION INPUT ; USE SIGNAL ;
            PORT LAYER M1 ; RECT 0.0 0.0 0.1 0.1 ; VIA 0.05 0.05 EXTERNAL_M1_M2 ; END
          END in
        END INV
        END LIBRARY
        """
        try await inspect(source) { result, binding in
            try #require(result.status == .completed, "\(result.diagnostics)")
            let observed = try #require(result.payload.inspection)
            #expect(observed.sourceArtifact == binding.reference)
            let document = try #require(observed.lefDocument)
            #expect(document.layers.isEmpty && document.vias.isEmpty)
            #expect(document.macros[0].pins[0].ports[0].vias[0].viaName == "EXTERNAL_M1_M2")
            #expect(!observed.layerNames.contains("M2") && !observed.layerNames.contains("ABSENT"))
            let report = PDKManifestViewBindingValidator().validate(manifest: manifest(layers: ["M2", "ABSENT"]),
                assetID: "cells", format: .lef, inspection: observed)
            #expect(!report.isValid && Set(report.missingLayerNames) == ["M2", "ABSENT"])
            #expect(report.findings.contains { $0.code == "pdk.standard-view.layer-binding-missing" })
        }
        try await inspect(source, expectedLayers: ["M2", "ABSENT"]) { result, _ in
            #expect(!result.payload.isValid)
            #expect(result.payload.findings.contains { $0.code == "pdk.standard-view.layer-binding-missing" })
        }
    }

    private func manifest(layers: [String]) -> PDKManifest {
        PDKManifest(processID: "referenced-layer-test", version: "1",
            layers: layers.enumerated().map { index, name in
                .init(layerID: name, name: name, number: index + 1, purpose: .drawing)
            }, crossViewMappings: [.init(mappingID: "cell-layers", view: .lef, assetID: "cells",
                physicalNames: ["INV"], layerIDs: layers)])
    }

    private func inspect(_ source: String, expectedLayers: [String] = [],
        body: (PDKStandardViewInspectionResult, TestArtifactBinding) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "pdk-referenced-layers-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record("Referenced-layer fixture cleanup failed: \(error)") }
        }
        let url = directory.appending(path: "cells.lef")
        let bytes = Data(source.utf8)
        try bytes.write(to: url, options: .atomic)
        let binding = try makeArtifactBinding(path: url.path, kind: .technology, format: .lef,
            sha256: SHA256ContentDigester().digest(data: bytes).hexadecimalValue, byteCount: Int64(bytes.count))
        let result = try await LocalPDKStandardViewInspector().execute(.init(runID: "referenced-layers",
            inputs: [binding.locator], format: .lef, assetID: "cells", expectedLayerNames: expectedLayers))
        try await body(result, binding)
        #expect(try Data(contentsOf: url) == bytes)
    }
}
