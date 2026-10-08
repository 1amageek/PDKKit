import CircuiteFoundation
import Foundation
import PDKCore
@testable import PDKProfileAdmission
import PDKSourceCapture
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ProfileAdmissionTests {
    @Test func exactAdmissionRetainsRequiredSupportAndLastCopiedOwner() async throws {
        let fixture = try await AdmissionFixture.make(support: true); defer { fixture.cleanup() }
        let probe = AdmissionCaptureProbe()
        let inspector = AdmissionScriptInspector(edges: [])
        var admitted: AdmittedPDKProfile? = try await LocalPDKProfileAdmitter(inspectors: [inspector.registration()], capture: probe).admit(fixture.request)
        var copy = admitted
        var factsCopy = admitted?.sourceFacts
        let resources = try #require(probe.resources)
        let held = resources.used(.liveOwnedBytes)
        #expect(admitted?.claim.mandatorySupportSourceKeys == ["support"])
        #expect(admitted?.sourceInputs.count == 2)
        #expect(admitted?.rootOccurrences.filter { $0.isMandatorySupport }.count == 1)
        #expect(resources.used(.readBytes) == fixture.expectedReadBytes)
        #expect(held > 0)
        #expect(throws: PDKAdmissionResourceError.closed) { try resources.check() }
        admitted = nil
        #expect(copy?.claim.definition.profileID == "fixture")
        #expect(resources.used(.liveOwnedBytes) == held)
        copy = nil
        #expect(factsCopy?.count == 2)
        #expect(resources.used(.liveOwnedBytes) > 0)
        factsCopy = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.openResources) == 0)
        #expect(resources.used(.concurrentAcquisitions) == 0)
    }
    @Test func sameContentWithDistinctDescriptorsUsesOneAcquisition() async throws {
        let fixture = try await AdmissionFixture.make(alias: true); defer { fixture.cleanup() }
        let probe = AdmissionCaptureProbe()
        let admitted = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: []).registration()], capture: probe).admit(fixture.request)
        #expect(admitted.claim.sourceClosure.count == 2)
        #expect(admitted.sourceInputs[0].reference.id == admitted.sourceInputs[1].reference.id)
        #expect(admitted.sourceInputs[0].reference.descriptor != admitted.sourceInputs[1].reference.descriptor)
        #expect(probe.references.filter { $0.id == fixture.rootReference.id }.count == 1)
        #expect(probe.resources?.used(.readBytes) == fixture.expectedReadBytes)
        #expect(probe.resources?.used(.uniqueSources) == 3)
    }
    @Test func repeatedNonrecursiveOccurrencesPreserveLexicalOrderAndReuseBytes() async throws {
        let fixture = try await AdmissionFixture.make(graph: .repeated); defer { fixture.cleanup() }
        let probe = AdmissionCaptureProbe()
        let admitted = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: fixture.definition.dependencies).registration()], capture: probe).admit(fixture.request)
        #expect(admitted.claim.dependencies.map(\.lexicalOrder) == [1, 2])
        #expect(admitted.sourceInputs.count == 3)
        #expect(admitted.dependencies[0].childNodeID != admitted.dependencies[1].childNodeID)
        #expect(admitted.dependencies[0].parentContext == admitted.dependencies[1].parentContext)
        #expect(probe.references.filter { $0.id == fixture.childReference?.id }.count == 1)
        #expect(probe.resources?.used(.readBytes) == fixture.expectedReadBytes)
        #expect(probe.resources?.used(.dependencyEdges) == 2)
    }
    @Test(arguments: [AdmissionFixture.Graph.cycle, .inactive])
    func contextualCyclesAndUnobservedApprovedEdgesRefuseAdmission(graph: AdmissionFixture.Graph) async throws {
        let fixture = try await AdmissionFixture.make(graph: graph); defer { fixture.cleanup() }
        let probe = AdmissionCaptureProbe()
        let edges = graph == .inactive ? [] : fixture.definition.dependencies
        do {
            _ = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: edges).registration()], capture: probe).admit(fixture.request)
            Issue.record("An invalid contextual closure was admitted")
        } catch let error as PDKProfileAdmissionError {
            #expect(error == (graph == .cycle ? .contextualCycle : .dependencyDrift))
        }
        #expect(probe.resources?.used(.liveOwnedBytes) == 0)
        #expect(probe.resources?.used(.openResources) == 0)
    }
    @Test func aProviderCannotSuppressTheResolversRecordedFailure() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let probe = AdmissionCaptureProbe()
        do {
            let inspector = AdmissionScriptInspector(edges: [], behavior: .suppressResolutionFailure)
            _ = try await LocalPDKProfileAdmitter(inspectors: [inspector.registration()], capture: probe).admit(fixture.request)
            Issue.record("Suppressed dependency failure authenticated admission")
        } catch let error as PDKProfileAdmissionError { #expect(error == .dependencyDrift) }
        #expect(probe.resources?.used(.liveOwnedBytes) == 0)
    }
    @Test(arguments: [AdmissionScriptInspector.Behavior.empty, .wrongIdentity, .wrongMapping, .wrongSection, .omitCoverage, .omitEvents, .unsupported])
    func providerClaimsAreCheckedIndependently(behavior: AdmissionScriptInspector.Behavior) async throws {
        let fixture = try await AdmissionFixture.make(graph: .nested); defer { fixture.cleanup() }
        let probe = AdmissionCaptureProbe()
        do {
            let inspector = AdmissionScriptInspector(edges: fixture.definition.dependencies, behavior: behavior)
            _ = try await LocalPDKProfileAdmitter(inspectors: [inspector.registration()], capture: probe).admit(fixture.request)
            Issue.record("False provider facts were admitted")
        } catch let error as PDKProfileAdmissionError {
            switch behavior {
            case .empty, .wrongSection, .omitCoverage: #expect(error == .missingCoverage)
            case .wrongIdentity: #expect(error == .providerIdentity)
            case .wrongMapping: #expect(error == .mappingMismatch)
            case .omitEvents: #expect(error == .dependencyDrift)
            case .unsupported: #expect(error == .unsupportedSemantics)
            default: Issue.record("Unexpected behavior")
            }
        }
        #expect(probe.resources?.used(.liveOwnedBytes) == 0)
        #expect(probe.resources?.used(.temporaryBytes) == 0)
        #expect(probe.resources?.used(.openResources) == 0)
    }
    @Test(arguments: ["profile.json", "pdk.json", "root.sp"])
    func exactInputTamperingCannotDiscoverReplacementIdentity(path: String) async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let target = fixture.root.appending(path: path)
        var bytes = try Data(contentsOf: target); bytes[0] ^= 1; try bytes.write(to: target)
        let probe = AdmissionCaptureProbe()
        do {
            _ = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: []).registration()], capture: probe).admit(fixture.request)
            Issue.record("Changed exact input was admitted")
        } catch let error as PDKProfileAdmissionError {
            switch error.underlyingReason {
            case .source(.digestMismatch), .manifest(.source(.digestMismatch)): break
            default: Issue.record("Unexpected exact failure: \(error)")
            }
        }
        #expect(probe.resources?.used(.liveOwnedBytes) == 0)
        #expect(probe.resources?.used(.openResources) == 0)
    }
    @Test(arguments: [AdmissionScriptInspector.Behavior.normal, .wrongPVT, .nominalOnly])
    func operatingPVTIsIndependentOfModelNominalTemperature(behavior: AdmissionScriptInspector.Behavior) async throws {
        let fixture = try await AdmissionFixture.make(corner: true, demandPVT: true); defer { fixture.cleanup() }
        let probe = AdmissionCaptureProbe()
        do {
            let admitted = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: [], behavior: behavior).registration()], capture: probe).admit(fixture.request)
            #expect(behavior == .normal)
            #expect(admitted.sourceFacts[0].pvt[0].kind == "operating")
            #expect(admitted.claim.corners[0].pvt.temperatureCelsius == 25)
        } catch let error as PDKProfileAdmissionError {
            #expect(behavior != .normal)
            #expect(error == (behavior == .wrongPVT ? .pvtMismatch : .missingCoverage))
        }
        #expect(probe.resources?.used(.liveOwnedBytes) == 0)
    }
    @Test(arguments: [PDKAdmissionResourceDimension.readBytes, .uniqueSources, .includeDepth, .parserWork])
    func cumulativeAndDepthLimitsApplyToTheActualAdmissionPath(dimension: PDKAdmissionResourceDimension) async throws {
        let fixture = try await AdmissionFixture.make(graph: .nested); defer { fixture.cleanup() }
        let baseline = AdmissionCaptureProbe()
        var result: AdmittedPDKProfile? = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: fixture.definition.dependencies).registration()], capture: baseline).admit(fixture.request)
        #expect(result?.claim.dependencies.count == 1)
        result = nil
        var limits = fixture.request.budget.limits
        switch dimension {
        case .includeDepth: limits[dimension] = 1
        default: limits[dimension] = try #require(baseline.resources).used(dimension) - 1
        }
        let budget = try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: fixture.request.budget.maximumElapsedNanoseconds)
        let probe = AdmissionCaptureProbe()
        do {
            _ = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: fixture.definition.dependencies).registration()], capture: probe).admit(fixture.replacingBudget(budget))
            Issue.record("An invocation resource limit was reset or bypassed")
        } catch let error as PDKProfileAdmissionError {
            #expect(exhausted(error) == dimension)
        }
        #expect(probe.resources?.used(.liveOwnedBytes) == 0)
        #expect(probe.resources?.used(.temporaryBytes) == 0)
        #expect(probe.resources?.used(.openResources) == 0)
    }
    @Test func explicitAvailabilityRejectsAmbiguousRootsAndMissingBindings() async throws {
        let fixture = try await AdmissionFixture.make(); defer { fixture.cleanup() }
        let base = fixture.request
        let cases: [(PDKProfileAdmissionRequest, PDKProfileAdmissionError)] = [
            (.init(definition: base.definition, manifest: base.manifest, roots: base.roots + base.roots,
                sources: base.sources, budget: base.budget, inspectionPolicyIdentity: base.inspectionPolicyIdentity), .ambiguousAvailability),
            (.init(definition: base.definition, manifest: base.manifest, roots: base.roots,
                sources: [], budget: base.budget, inspectionPolicyIdentity: base.inspectionPolicyIdentity), .missingBinding)]
        for (request, expected) in cases {
            do {
                _ = try await LocalPDKProfileAdmitter(inspectors: [AdmissionScriptInspector(edges: []).registration()]).admit(request)
                Issue.record("Implicit filesystem authority supplied a missing binding")
            } catch let error as PDKProfileAdmissionError { #expect(error == expected) }
        }
    }
    private func exhausted(_ error: PDKProfileAdmissionError) -> PDKAdmissionResourceDimension? {
        switch error {
        case .resource(.exhausted(let dimension, _, _)), .selection(.resource(.exhausted(let dimension, _, _))),
             .source(.resource(.exhausted(let dimension, _, _))), .definition(.resource(.exhausted(let dimension, _, _))),
             .inspection(.resource(.exhausted(let dimension, _, _))),
             .manifest(.decode(.resource(.exhausted(let dimension, _, _)))), .manifest(.source(.resource(.exhausted(let dimension, _, _)))):
            dimension
        default: nil
        }
    }
}
