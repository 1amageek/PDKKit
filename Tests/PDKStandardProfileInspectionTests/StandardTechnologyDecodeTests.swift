import CircuiteFoundation
import Foundation
import PDKCore
import PDKDiscovery
@testable import PDKProfileAdmission
import PDKSourceCapture
import PDKStandardViews
import TechIR
import Testing

struct StandardTechnologyDecodeTests {
    @Test func actualTypedCaptureStrictDecodeAndLastCopy() async throws {
        let fixture = try await StandardProfileFixture.make(); defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.budget)
        var captured: CapturedPDKSource? = try await fixture.capture(resources: resources)
        var document: PDKDecodedDocument<IRTechLibrary>? = try NativePDKStandardTechnologyDecoder().decodeTechnology(#require(captured), resources: resources)
        #expect(document?.value == StandardProfileFixture.library)
        #expect(document?.sourceReference == fixture.reference)
        #expect(document?.value.layers[0].gdsLayer == -7)
        #expect(resources.used(.temporaryBytes) == 0)
        var copy = document
        document = nil; captured = nil
        #expect(copy?.value.layers[0].name == "M1")
        #expect(resources.used(.liveOwnedBytes) > 0)
        copy = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
    }
    @Test func currentProcessFactsRetainTypedValuesAndSourceBinding() async throws {
        let library = StandardProfileFixture.retainedProcessLibrary
        let fixture = try await StandardProfileFixture.make(library: library); defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.budget)
        let captured = try await fixture.capture(resources: resources)
        let document = try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources)
        #expect(document.value == library)
        #expect(document.sourceReference == fixture.reference)
        #expect(document.value.layers[2].currentDensityLimits[0].quantity == .milliamperesPerSquareMicron(0.36))
        #expect(document.value.viaGenerationRules[0].cutCenterSpacing == .xy(x: 0.4, y: 0.7))
        #expect(resources.used(.temporaryBytes) == 0)
    }
    @Test func legacyRootOmissionsKeepStandardDefaults() async throws {
        let library = StandardProfileFixture.library
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(library)) as? [String: Any])
        for key in ["manufacturingGrid", "unitDeclarations", "hasDatabaseUnitsDeclaration",
                    "obstructionSpacingUsesMinimumWidth", "propertyDefinitions", "viaGenerationRules"] {
            object.removeValue(forKey: key)
        }
        let fixture = try await StandardProfileFixture.make(bytes: JSONSerialization.data(withJSONObject: object)); defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.budget)
        let captured = try await fixture.capture(resources: resources)
        let document = try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources)
        #expect(document.value == library)
        #expect(document.sourceReference == fixture.reference)
    }
    @Test(arguments: ["manufacturingGrid", "unitDeclarations", "hasDatabaseUnitsDeclaration",
                      "obstructionSpacingUsesMinimumWidth", "propertyDefinitions", "viaGenerationRules", "futureNested"])
    func malformedRecognizedOrFutureNestedFieldsRefuse(_ field: String) async throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(StandardProfileFixture.retainedProcessLibrary)) as? [String: Any])
        if field == "futureNested" {
            var rules = try #require(object["viaGenerationRules"] as? [[String: Any]])
            rules[0]["futureSelector"] = true; object["viaGenerationRules"] = rules
        } else { object[field] = "invalid type" }
        let fixture = try await StandardProfileFixture.make(bytes: JSONSerialization.data(withJSONObject: object)); defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.budget)
        let captured = try await fixture.capture(resources: resources)
        let baseline = resources.used(.liveOwnedBytes)
        #expect(throws: PDKBoundedDecodeError.self) {
            try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources)
        }
        #expect(resources.used(.liveOwnedBytes) == baseline)
        #expect(resources.used(.temporaryBytes) == 0)
    }
    @Test func unknownRootNestedFieldsAndMetadataRefuse() async throws {
        let base = try JSONEncoder().encode(StandardProfileFixture.library)
        for path in ["root", "nested", "metadata", "otherSchema"] {
            var object = try #require(JSONSerialization.jsonObject(with: base) as? [String: Any])
            switch path {
            case "root": object["include"] = "other.json"
            case "nested":
                var layers = try #require(object["layers"] as? [[String: Any]])
                layers[0]["include"] = "other.json"; object["layers"] = layers
            case "metadata": object["metadata"] = ["include": "other.json"]
            default: object = ["stack": [], "processName": "p"]
            }
            let fixture = try await StandardProfileFixture.make(bytes: JSONSerialization.data(withJSONObject: object))
            defer { fixture.remove() }
            let resources = LocalPDKAdmissionResources(budget: fixture.budget)
            let captured = try await fixture.capture(resources: resources)
            let baseline = resources.used(.liveOwnedBytes)
            do { _ = try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources); Issue.record("Unsupported schema succeeded") }
            catch { guard case .unsupportedValue = error else { Issue.record("Wrong refusal: \(error)"); continue } }
            #expect(resources.used(.liveOwnedBytes) == baseline)
            #expect(resources.used(.temporaryBytes) == 0)
        }
    }
    @Test func malformedDuplicateAndDeepUnusedDataRefuse() async throws {
        for bytes in [Data("{\"name\":\"a\",\"name\":\"b\"}".utf8), Data([0xff]),
                      Data(("{\"unknown\":" + String(repeating: "[", count: 2048) + "0" + String(repeating: "]", count: 2048) + "}").utf8)] {
            let fixture = try await StandardProfileFixture.make(bytes: bytes)
            defer { fixture.remove() }
            let resources = LocalPDKAdmissionResources(budget: fixture.budget)
            let captured = try await fixture.capture(resources: resources)
            let baseline = resources.used(.liveOwnedBytes)
            #expect(throws: PDKBoundedDecodeError.self) { try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources) }
            #expect(resources.used(.liveOwnedBytes) == baseline)
            #expect(resources.used(.temporaryBytes) == 0)
            #expect(resources.used(.decodeNesting) == 0)
        }
    }
    @Test func actualDecodeQuotaAndCumulativeWorkUnwind() async throws {
        let fixture = try await StandardProfileFixture.make(); defer { fixture.remove() }
        let captureResources = LocalPDKAdmissionResources(budget: fixture.budget)
        let captured = try await fixture.capture(resources: captureResources)
        for dimension in [PDKAdmissionResourceDimension.parserWork, .decodedElements, .scalarBytes, .decodeNesting, .temporaryBytes, .liveOwnedBytes] {
            let resources = LocalPDKAdmissionResources(budget: try StandardProfileFixture.budget(limits: [dimension: 1]))
            do { _ = try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources); Issue.record("Quota succeeded") }
            catch { guard case .resource(.exhausted(let actual, _, _)) = error else { Issue.record("Wrong quota refusal: \(error)"); continue }; #expect(actual == dimension) }
            #expect(resources.used(.temporaryBytes) == 0); #expect(resources.used(.liveOwnedBytes) == 0)
        }
        let measured = LocalPDKAdmissionResources(budget: fixture.budget)
        _ = try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: measured)
        let work = measured.used(.parserWork)
        let resources = LocalPDKAdmissionResources(budget: try StandardProfileFixture.budget(limits: [.parserWork: work]))
        _ = try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources)
        do {
            _ = try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources)
            Issue.record("Cumulative decode work reset")
        } catch {
            guard case .resource(.exhausted(let dimension, let limit, let attempted)) = error else {
                Issue.record("Wrong cumulative refusal: \(error)")
                return
            }
            #expect(dimension == .parserWork)
            #expect(limit == work)
            #expect(attempted > work)
        }
        #expect(resources.used(.parserWork) == work)
        #expect(resources.used(.liveOwnedBytes) == 0)
    }
    @Test func actualTaskCancellationAndOriginalDeadlineRefuse() async throws {
        let fixture = try await StandardProfileFixture.make(); defer { fixture.remove() }
        let captureResources = LocalPDKAdmissionResources(budget: fixture.budget)
        let captured = try await fixture.capture(resources: captureResources)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let resources = LocalPDKAdmissionResources(budget: fixture.budget)
            do { _ = try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: resources); Issue.record("Cancelled decode succeeded") }
            catch { #expect((error as? PDKBoundedDecodeError) == .resource(.cancelled)) }
            #expect(resources.used(.liveOwnedBytes) == 0)
        }
        await task.value
        let expired = LocalPDKAdmissionResources(budget: try StandardProfileFixture.budget(elapsed: 1))
        #expect(throws: PDKBoundedDecodeError.resource(.deadlineExceeded)) {
            try NativePDKStandardTechnologyDecoder().decodeTechnology(captured, resources: expired)
        }
    }
}
