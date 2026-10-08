import CircuiteFoundation
import Foundation
import PDKCore
@testable import PDKDiscovery
@testable import PDKProfileAdmission
import PDKSourceCapture
import PDKStandardViews
import Synchronization
import TechIR
import Testing

@Suite(.timeLimit(.minutes(1)))
struct StandardProfileAdmissionTests {
    @Test func actualCapturedTechnologyPublishesOnlyObservedFacts() async throws {
        let fixture = try await StandardProfileFixture.make(corner: true)
        defer { fixture.remove() }
        let capture = StandardCaptureProbe(deleteTechnology: true)
        let registration = try PDKStandardProfileInspection.technologyRegistration(policyIdentity: "policy.v1")
        let profile = try await LocalPDKProfileAdmitter(inspectors: [registration], capture: capture).admit(fixture.request)
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appending(path: "technology.json").path))
        let facts = try #require(profile.sourceFacts.first)
        #expect(profile.sourceFacts.count == 1)
        #expect(facts.input.reference == fixture.reference)
        #expect(facts.input.context.preprocessingIdentity == "shared.mixed-format.provenance")
        #expect(facts.input.context.cornerID == "tt")
        #expect(facts.mappings.map(\.factKind) == ["layers", "vias", "sites"])
        #expect(facts.mappings.map(\.name) == ["M1", "V1", "S1"])
        #expect(facts.mappings[0].layerNumber == -7)
        #expect(facts.mappings[0].layerPurpose == nil)
        #expect(facts.mappings.allSatisfy { $0.input.reference == fixture.reference && $0.terminals.isEmpty })
        #expect(facts.pvt.isEmpty && facts.temperatures.isEmpty && facts.events.isEmpty)
        let coverage = try #require(facts.coverage.first)
        #expect(facts.coverage.count == 1)
        #expect(coverage.meaning == .leaf && coverage.observedSection == nil)
        #expect(coverage.activeDependencies.isEmpty && coverage.inactiveStatementOffsets.isEmpty)
        #expect(profile.dependencies.isEmpty)
    }

    @Test func manifestCannotSupplyMissingPurposeOrPhysicalName() async throws {
        var library = StandardProfileFixture.library
        library.layers[0].gdsLayer = 1
        let purposeFixture = try await StandardProfileFixture.make(library: library, fullLayer: true)
        defer { purposeFixture.remove() }
        try await refusal(purposeFixture, expected: .mappingMismatch)
        let nameFixture = try await StandardProfileFixture.make(physicalNames: ["invented-layer"])
        defer { nameFixture.remove() }
        try await refusal(nameFixture, expected: .mappingMismatch)
    }

    @Test(arguments: ["sourcePVT", "operatingTemperature", "selectedSection", "devices", "unknown"])
    func unavailableFactDemandRefuses(_ demand: String) async throws {
        let fixture = try await StandardProfileFixture.make(demands: [demand], corner: true)
        defer { fixture.remove() }
        try await refusal(fixture, expected: .inspection(.unsupportedSemantics))
    }

    @Test func unavailableSectionAndViewRefuse() async throws {
        let section = try await StandardProfileFixture.make(section: "tt")
        defer { section.remove() }
        try await refusal(section, expected: .inspection(.unsupportedSemantics))
        for view in [PDKViewKind.extraction, .ruleDeck, .liberty] {
            let fixture = try await StandardProfileFixture.make(view: view)
            defer { fixture.remove() }
            try await refusal(fixture, expected: .inspection(.unsupportedSemantics))
        }
    }

    @Test(arguments: [ArtifactFormat.lef, .gdsii, .oasis, .liberty])
    func opaqueFormatRefusesBeforeDecoder(_ format: ArtifactFormat) async throws {
        let fixture = try await StandardProfileFixture.make(format: format)
        defer { fixture.remove() }
        let decoder = RefusingTechnologyDecoder()
        let registration = try PDKProfileInspectorRegistration(format: format,
            parserIdentity: NativePDKStandardProfileInspector.unsupportedParserIdentity, policyIdentity: "policy.v1",
            inspector: NativePDKStandardProfileInspector(format: format, policyIdentity: "policy.v1", technologyDecoder: decoder))
        try await refusal(fixture, registration: registration,
            expected: .inspection(.resource(.unsupportedBudgetCapability("Standard profile codec accounting is unavailable"))))
        #expect(decoder.calls == 0)
    }

    @Test(arguments: [false, true])
    func decodedFullDescriptorOrMissingBindingRefuses(_ missing: Bool) async throws {
        let fixture = try await StandardProfileFixture.make()
        defer { fixture.remove() }
        let registration = try PDKStandardProfileInspection.technologyRegistration(policyIdentity: "policy.v1",
            decoder: SubstitutingTechnologyDecoder(missing: missing))
        try await refusal(fixture, registration: registration, expected: .inspection(.invalidFacts))
    }

    private func refusal(_ fixture: StandardProfileFixture, registration: PDKProfileInspectorRegistration? = nil,
                         expected: PDKProfileAdmissionError) async throws {
        let selected = try registration ?? PDKStandardProfileInspection.technologyRegistration(policyIdentity: "policy.v1")
        do {
            _ = try await LocalPDKProfileAdmitter(inspectors: [selected]).admit(fixture.request)
            Issue.record("Unsupported or unauthenticated profile succeeded")
        } catch {
            #expect(error.underlyingReason == expected)
        }
    }
}

private final class RefusingTechnologyDecoder: PDKStandardTechnologyDecoding {
    private let count = Mutex(0)
    var calls: Int { count.withLock { $0 } }
    func decodeTechnology(_ source: CapturedPDKSource, resources: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<IRTechLibrary> {
        count.withLock { $0 += 1 }
        throw .unsupportedValue("Decoder must not run for an opaque format")
    }
}

private struct SubstitutingTechnologyDecoder: PDKStandardTechnologyDecoding {
    let missing: Bool
    func decodeTechnology(_ source: CapturedPDKSource, resources: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<IRTechLibrary> {
        let actual = try NativePDKStandardTechnologyDecoder().decodeTechnology(source, resources: resources)
        if missing { return .init(value: actual.value, reservations: [], sourceReference: nil) }
        let original = source.reference
        let foreign = ArtifactReference(id: original.id, descriptor: .init(role: .output,
            kind: original.descriptor.kind, format: original.descriptor.format))
        return actual.binding(to: foreign)
    }
}
