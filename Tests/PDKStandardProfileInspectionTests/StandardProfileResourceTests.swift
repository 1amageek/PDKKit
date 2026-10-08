import Foundation
import PDKCore
@testable import PDKProfileAdmission
import PDKStandardViews
import TechIR
import Testing

struct StandardProfileResourceTests {
    private struct NoDependencies: PDKProfileDependencyResolving {
        func resolve(_ request: PDKProfileDependencyRequest) async throws(PDKProfileAdmissionError) -> PDKProfileSourceInput {
            Issue.record("Data-only inspection attempted dependency resolution")
            throw .unsupportedSemantics
        }
    }
    private func admit(_ fixture: StandardProfileFixture, probe: StandardCaptureProbe = .init()) async throws -> AdmittedPDKProfile {
        try await LocalPDKProfileAdmitter(inspectors: [PDKStandardProfileInspection.technologyRegistration(policyIdentity: "policy.v1")],
            capture: probe).admit(fixture.request)
    }
    private func inspect(_ profile: AdmittedPDKProfile, resources: any PDKAdmissionResourceAccounting) async throws(PDKProfileInspectionError) -> PDKProfileSourceFacts {
        let request = PDKProfileSourceInspectionRequest(input: profile.sourceInputs[0], requirementID: "technology", view: .layerMap,
            corner: nil, demandedFactKinds: ["layers", "vias", "sites", "dependencyClosure"], policy: "policy.v1")
        return try await NativePDKStandardProfileInspector(format: .json, policyIdentity: "policy.v1")
            .inspect(request, dependencies: NoDependencies(), resources: resources)
    }
    @Test func copiedFactsRetainAccountedBackingAndOriginalSource() async throws {
        let fixture = try await StandardProfileFixture.make(); defer { fixture.remove() }
        let probe = StandardCaptureProbe()
        var profile: AdmittedPDKProfile? = try await admit(fixture, probe: probe)
        let originalResources = try #require(probe.resources)
        let resources = LocalPDKAdmissionResources(budget: fixture.budget)
        var facts: PDKProfileSourceFacts? = try await inspect(#require(profile), resources: resources)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.liveOwnedBytes) > 0)
        #expect(resources.used(.readBytes) == 0)
        #expect(resources.used(.uniqueSources) == 0)
        var copy = facts
        facts = nil; profile = nil
        #expect(copy?.mappings[0].layerNumber == -7)
        #expect(copy?.input.reference == fixture.reference)
        #expect(originalResources.used(.liveOwnedBytes) > 0)
        resources.close()
        #expect(throws: PDKAdmissionResourceError.closed) { try resources.check() }
        copy = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(originalResources.used(.liveOwnedBytes) == 0)
    }
    @Test func actualInspectionQuotaAndCumulativeProjectionWorkUnwind() async throws {
        let fixture = try await StandardProfileFixture.make(); defer { fixture.remove() }
        let profile = try await admit(fixture)
        for dimension in [PDKAdmissionResourceDimension.parserWork, .decodedElements, .scalarBytes, .decodeNesting, .temporaryBytes, .liveOwnedBytes] {
            let resources = LocalPDKAdmissionResources(budget: try StandardProfileFixture.budget(limits: [dimension: 1]))
            do { _ = try await inspect(profile, resources: resources); Issue.record("Inspection ignored quota") }
            catch { guard case .resource(.exhausted(let actual, _, _)) = error else { Issue.record("Wrong quota failure: \(error)"); continue }; #expect(actual == dimension) }
            #expect(resources.used(.temporaryBytes) == 0); #expect(resources.used(.liveOwnedBytes) == 0)
        }
        let measured = LocalPDKAdmissionResources(budget: fixture.budget)
        _ = try await inspect(profile, resources: measured)
        let work = measured.used(.parserWork)
        let resources = LocalPDKAdmissionResources(budget: try StandardProfileFixture.budget(limits: [.parserWork: work]))
        _ = try await inspect(profile, resources: resources)
        do { _ = try await inspect(profile, resources: resources); Issue.record("Cumulative inspection work reset") }
        catch { #expect(error == .resource(.exhausted(dimension: .parserWork, limit: work, attempted: work + 1))) }
        #expect(resources.used(.liveOwnedBytes) == 0); #expect(resources.used(.temporaryBytes) == 0)
    }
    @Test func structuredTaskCancellationAndElapsedDeadlineStayTyped() async throws {
        let fixture = try await StandardProfileFixture.make(); defer { fixture.remove() }
        let profile = try await admit(fixture)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let resources = LocalPDKAdmissionResources(budget: fixture.budget)
            do { _ = try await inspect(profile, resources: resources); Issue.record("Cancelled inspection succeeded") }
            catch { #expect((error as? PDKProfileInspectionError) == .resource(.cancelled)) }
            #expect(resources.used(.liveOwnedBytes) == 0)
        }
        await task.value
        let resources = LocalPDKAdmissionResources(budget: try StandardProfileFixture.budget(elapsed: 1))
        do { _ = try await inspect(profile, resources: resources); Issue.record("Expired inspection succeeded") }
        catch { #expect(error == .resource(.deadlineExceeded)) }
        #expect(resources.used(.liveOwnedBytes) == 0)
    }
    @Test func zeroObservationsCanProveLeafButCannotSatisfyLayers() async throws {
        let fixture = try await StandardProfileFixture.make(library: IRTechLibrary(name: "empty"),
            demands: ["dependencyClosure"], physicalNames: [])
        defer { fixture.remove() }
        let profile = try await admit(fixture)
        #expect(profile.sourceFacts[0].mappings.isEmpty)
        #expect(profile.sourceFacts[0].coverage.count == 1)
        let required = try await StandardProfileFixture.make(library: IRTechLibrary(name: "empty"), demands: ["layers"], physicalNames: [])
        defer { required.remove() }
        do { _ = try await admit(required); Issue.record("Empty observations satisfied required layers") }
        catch let error as PDKProfileAdmissionError { #expect(error.underlyingReason == .missingCoverage) }
    }
}
