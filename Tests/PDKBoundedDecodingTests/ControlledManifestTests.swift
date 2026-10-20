import Foundation
import Testing
import PDKCore
import PDKDiscovery
import CircuiteFoundation

@Suite(.timeLimit(.minutes(1))) struct ControlledManifestTests {
    private func load(_ bytes: [UInt8], _ accounting: DecodeTestAccounting) throws -> PDKControlledManifest {
        let decoder: any PDKControlledManifestDecoding = NativePDKBoundedDocumentDecoder()
        return try decoder.decodeAndValidateManifest(bytes: bytes.span, accounting: accounting)
    }

    private func expectCause(_ expected: PDKBoundedDecodeError, _ operation: () throws -> Void) {
        do { try operation(); Issue.record("Expected controlled decode failure") }
        catch let failure as PDKControlledDecodeFailure { #expect(failure.cause == expected) }
        catch { Issue.record("Unexpected failure type: \(error)") }
    }

    @Test func rawPublicBorrowHasNoAuthorityAndRetainsEscapedCollections() throws {
        let bytes = Array(#"{"key":["\u0061","\uD83D\uDE00"],"unknown":[1,2]}"#.utf8)
        let accounting = DecodeTestAccounting()
        var first: PDKDecodedDocument<[String: [String]]>?
        let known = Array(#"{"key":["\u0061","\uD83D\uDE00"]}"#.utf8)
        first = try NativePDKBoundedDocumentDecoder().decodeAudited([String: [String]].self,
            bytes: known.span, accounting: accounting, rejectUnknownFields: true, validate: { _ in })
        #expect(first?.value == ["key": ["a", "😀"]])
        #expect(first?.sourceReference == nil)
        var copy = first
        first = nil
        #expect(copy?.value["key"]?.count == 2)
        #expect(accounting.amount(.liveOwnedBytes) > 0)
        copy = nil
        #expect(accounting.amount(.liveOwnedBytes) == 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
        // A dictionary's keys remain data even in strict-field mode; incompatible values refuse.
        #expect(throws: PDKControlledDecodeFailure.self) {
            try NativePDKBoundedDocumentDecoder().decodeAudited([String: [String]].self,
                bytes: bytes.span, accounting: accounting, rejectUnknownFields: true, validate: { _ in })
        }
    }

    @Test func controlledRulesMatchOrdinaryValuesAndCompleteFindings() throws {
        var valid = try BoundedDecodeFixture.values().0
        valid.layers = [PDKLayerDefinition(layerID: "M1", name: "metal1", number: 1, purpose: .metal)]
        valid.devices = [PDKDeviceDefinition(deviceID: "nmos", modelName: "nch",
            terminals: [PDKDeviceTerminal(name: "D", role: .bidirectional, order: 0)])]
        #expect(valid.validate().isValid)
        var invalid = valid
        invalid.processID = " \n\t"
        invalid.assets.append(invalid.assets[0])
        invalid.assets[0].path = "/absolute.sp"
        invalid.assets[0].cornerIDs.append("missing")
        invalid.corners[0].assetIDs.append("missing")
        invalid.crossViewMappings[0].layerIDs.append("missing")
        for manifest in [valid, invalid, PDKManifest(processID: "p", version: "1")] {
            let bytes = Array(try PDKManifestCodec.encode(manifest))
            let resources = DecodeTestAccounting()
            let loaded = try load(bytes, resources)
            let ordinary = try PDKManifestCodec.decode(data: Data(bytes))
            #expect(loaded.manifest == ordinary)
            #expect(loaded.validation == loaded.manifest.validate())
            #expect(resources.amount(.diagnosticEntries) == UInt64(loaded.validation.findings.count))
            #expect(resources.amount(.temporaryBytes) == 0)
        }
    }

    @Test func asciiNormalizationIsAdmittedAndUnicodeIsExplicitCapabilityFailure() throws {
        var manifest = try BoundedDecodeFixture.values().0
        manifest.assets[0].format = try ArtifactFormat(rawValue: String(repeating: "A", count: 512))
        let bytes = Array(try PDKManifestCodec.encode(manifest))
        let resources = DecodeTestAccounting()
        let loaded = try load(bytes, resources)
        #expect(loaded.manifest.assets[0].format.rawValue == String(repeating: "a", count: 512))
        let scalarCount = resources.amount(.scalarBytes)
        let refused = DecodeTestAccounting(limits: [.scalarBytes: scalarCount - 1])
        #expect(throws: PDKControlledDecodeFailure.self) { try load(bytes, refused) }
        #expect(refused.amount(.liveOwnedBytes) == 0)
        #expect(refused.amount(.temporaryBytes) == 0)
        manifest.assets[0].format = try ArtifactFormat(rawValue: "ÄBC")
        let unicode = Array(try PDKManifestCodec.encode(manifest))
        #expect(try PDKManifestCodec.decode(data: Data(unicode)).assets[0].format.rawValue == "äbc")
        let unicodeResources = DecodeTestAccounting()
        expectCause(.resource(.unsupportedBudgetCapability("Cooperative Unicode manifest format normalization"))) {
            _ = try load(unicode, unicodeResources)
        }
        #expect(unicodeResources.amount(.liveOwnedBytes) == 0)
        #expect(unicodeResources.amount(.temporaryBytes) == 0)
    }

    @Test func tinyCapacityRefusesHugeArrayBeforeMaterializationAndUnknownFieldsRemainCompatible() throws {
        let manifest = PDKManifest(processID: "p", version: "1")
        let encoded = String(decoding: try PDKManifestCodec.encode(manifest), as: UTF8.self)
        let json = String(encoded.dropLast()) + ",\"unused\":[" + String(repeating: "0,", count: 9999) + "0]}"
        let resources = DecodeTestAccounting(limits: [.temporaryBytes: 64])
        #expect(throws: PDKControlledDecodeFailure.self) { try load(Array(json.utf8), resources) }
        #expect(resources.amount(.decodedElements) < 10000)
        #expect(resources.amount(.temporaryBytes) == 0)
        #expect(resources.amount(.liveOwnedBytes) == 0)
        let compatible = String(encoded.dropLast()) + ",\"unused\":{\"nested\":[1,2]}}"
        let compatibleBytes = Array(compatible.utf8)
        #expect(try load(compatibleBytes, DecodeTestAccounting()).manifest == manifest)
        #expect(throws: PDKControlledDecodeFailure.self) {
            try NativePDKBoundedDocumentDecoder().decodeAudited(PDKManifest.self, bytes: compatibleBytes.span,
                accounting: DecodeTestAccounting(), rejectUnknownFields: true, validate: { _ in })
        }
        expectCause(.manifest(.unsupportedSchemaVersion(2))) {
            _ = try load(Array(#"{"schemaVersion":2}"#.utf8), DecodeTestAccounting())
        }
    }

    @Test func validationCancellationAndFindingRefusalRefundBothOwners() throws {
        let bytes = Array(try PDKManifestCodec.encode(PDKManifest(processID: "p", version: "1")))
        let baseline = DecodeTestAccounting()
        _ = try NativePDKBoundedDocumentDecoder().decodeAudited(PDKManifest.self, bytes: bytes.span,
            accounting: baseline, rejectUnknownFields: false, validate: { _ in })
        let decodeChecks = baseline.state.withLock { $0.checks }
        let cancelled = DecodeTestAccounting(cancelAfterChecks: decodeChecks + 1)
        expectCause(.resource(.cancelled)) { _ = try load(bytes, cancelled) }
        #expect(cancelled.amount(.liveOwnedBytes) == 0)
        #expect(cancelled.amount(.temporaryBytes) == 0)
        let refused = DecodeTestAccounting(limits: [.diagnosticEntries: 1])
        #expect(throws: PDKControlledDecodeFailure.self) { try load(bytes, refused) }
        #expect(refused.amount(.liveOwnedBytes) == 0)
        #expect(refused.amount(.temporaryBytes) == 0)
        #expect(refused.amount(.diagnosticEntries) == 1)
    }

    @Test func retainedManifestAndReportReleaseOnlyAfterFinalCopy() throws {
        let resources = DecodeTestAccounting()
        let bytes = Array(try PDKManifestCodec.encode(PDKManifest(processID: "p", version: "1")))
        var first: PDKControlledManifest? = try load(bytes, resources)
        var second = first
        first = nil
        #expect(second?.validation.isValid == false)
        #expect(second?.manifest.processID == "p")
        #expect(resources.amount(.liveOwnedBytes) > 0)
        #expect(resources.amount(.temporaryBytes) == 0)
        second = nil
        #expect(resources.amount(.liveOwnedBytes) == 0)
    }
}
