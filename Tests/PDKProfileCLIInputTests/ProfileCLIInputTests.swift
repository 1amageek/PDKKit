import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation
import PDKCore
import PDKDiscovery
import PDKKitCLICore
import PDKProfileAdmission
import PDKSourceCapture
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ProfileCLIInputTests {
    @Test func checkedInputsRefuseUnknownRootsAndContradictoryCandidateAliases() async throws {
        let fixture = try await CLIInputFixture.make(); defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.budget); defer { resources.close() }
        let otherID = try ArtifactRootID(rawValue: "unregistered")
        let unknown = PDKProfileExactBinding(reference: fixture.manifest.reference, rootID: otherID,
            relativePath: fixture.manifest.relativePath, budget: fixture.access)
        do {
            _ = try await NativePDKProfileCLIInputLoader().loadAvailability(binding: unknown, root: fixture.root, resources: resources)
            Issue.record("Mismatched explicit root identity was accepted")
        } catch { #expect(error == .invalidBinding) }
        #expect(throws: PDKProfileCLIInputError.invalidBinding) {
            try PDKProfileCLIAvailability(roots: [fixture.root], definition: nil, manifest: unknown, sources: [], claim: nil,
                inspectionPolicyIdentity: "policy.v1", resources: resources)
        }
        #expect(throws: PDKProfileCLIInputError.invalidBinding) {
            try PDKProfileCLIAvailability(roots: [fixture.root, fixture.root], definition: nil, manifest: fixture.manifest,
                sources: [], claim: nil, inspectionPolicyIdentity: "policy.v1", resources: resources)
        }
        let alias = PDKProfileSourceBinding(sourceKey: "model", logicalRoute: "alias.sp", rootID: fixture.root.rootID,
            relativePath: try ArtifactRelativePath(segments: ["different.sp"]), budget: fixture.access)
        #expect(throws: PDKProfileCLIInputError.invalidBinding) {
            try PDKProfileCLICandidateSource(sourceKey: "model", assetID: "model", descriptor: .init(role: .input, kind: .model, format: .spice),
                logicalRoutes: ["model.sp", "alias.sp"], bindings: [fixture.source, alias], resources: resources)
        }
    }
    @Test func taskCancellationAfterOpenStopsReadAndAwaitsShutdown() async throws {
        let fixture = try await CLIInputFixture.make(); defer { fixture.remove() }
        let gate = CLIInputGate(), probe = CLIInputRootProbe(gate: gate)
        let access = try ArtifactAccessBudget(maximumPageByteCount: 100, maximumTotalByteCount: 100,
            maximumPageCount: 100, maximumWorkUnitCount: 1000, maximumDurationNanoseconds: 30_000_000_000)
        let task = Task {
            try await NativePDKProfileCLIInputLoader(roots: probe).loadBudget(root: fixture.root,
                relativePath: ArtifactRelativePath(segments: ["budget.json"]), policy: PDKBudgetBootstrapPolicy(maximumByteCount: 100), accessBudget: access)
        }
        await gate.waitForArrival(); task.cancel(); await gate.release()
        switch await task.result {
        case .success: Issue.record("Cancelled bootstrap succeeded")
        case .failure(let error):
            #expect(error as? PDKProfileCLIInputError == .discovery(.control(.cancelled)))
        }
        #expect(probe.state.withLock { $0.readBytes } == 0)
        #expect(probe.state.withLock { $0.shuts } == 1)
    }
    @Test func budgetRealRootReadsAndParsesTheSameOwnedInput() async throws {
        let fixture = try await CLIInputFixture.make(); defer { fixture.remove() }
        let bytes = try JSONEncoder().encode(fixture.budget)
        let binding = try await fixture.write(bytes, name: "budget.json")
        let access = try ArtifactAccessBudget(maximumPageByteCount: 16_384, maximumTotalByteCount: 16_384,
            maximumPageCount: 16_384, maximumWorkUnitCount: 32_768, maximumDurationNanoseconds: 30_000_000_000)
        let reader: any PDKProfileCLIInputLoading = NativePDKProfileCLIInputLoader()
        let loaded = try await reader.loadBudget(root: fixture.root, relativePath: binding.relativePath, policy: .standard, accessBudget: access)
        #expect(loaded.parsed.budget == fixture.budget)
        #expect(loaded.reference.digest == binding.reference.digest)
        #expect(loaded.parsed.inputByteCount == UInt64(bytes.count))
        #expect(loaded.acquisition.readByteCount == UInt64(bytes.count))
        #expect(loaded.acquisition.hashedByteCount == UInt64(bytes.count))
        #expect(loaded.acquisition.openResourceCount == 0)
        #expect(loaded.acquisition.temporaryByteCount == 0)
        #expect(loaded.acquisition.pageCount == 1)
        // POSIX openat admits the one path segment's UTF-8 C name plus its terminator.
        // A contiguous source copy would instead retain the complete input byte count.
        let pathScratch = UInt64(binding.relativePath.segments[0].utf8.count) + 1
        #expect(loaded.acquisition.peakTemporaryByteCount == pathScratch)
        #expect(UInt64(bytes.count) > pathScratch)
        #expect(loaded.acquisition.ownedByteCount >= UInt64(bytes.count))
        let copy = loaded
        #expect(copy.reference == loaded.reference)
    }
    @Test func bootstrapPolicyAndActualFileSizeRefuseBeforeRead() async throws {
        let fixture = try await CLIInputFixture.make(); defer { fixture.remove() }
        let probe = CLIInputRootProbe()
        let reader = NativePDKProfileCLIInputLoader(roots: probe)
        do {
            _ = try await reader.loadBudget(root: fixture.root, relativePath: ArtifactRelativePath(segments: ["budget.json"]),
                policy: PDKBudgetBootstrapPolicy(maximumByteCount: 10), accessBudget: fixture.access)
            Issue.record("Unbounded bootstrap source policy was accepted")
        } catch let error as PDKProfileCLIInputError { #expect(error == .invalidBootstrapPolicy) }
        #expect(probe.state.withLock { $0.opens } == 0)
        let incompatible = try ArtifactAccessBudget(maximumPageByteCount: 10, maximumTotalByteCount: 100,
            maximumPageCount: 100, maximumWorkUnitCount: 1000, maximumDurationNanoseconds: 30_000_000_000)
        do {
            _ = try await reader.loadBudget(root: fixture.root, relativePath: ArtifactRelativePath(segments: ["budget.json"]),
                policy: PDKBudgetBootstrapPolicy(maximumByteCount: 100), accessBudget: incompatible)
            Issue.record("Multi-page bootstrap acquisition was accepted")
        } catch let error as PDKProfileCLIInputError { #expect(error == .invalidBootstrapPolicy) }
        let unsupported = try ArtifactAccessBudget(maximumPageByteCount: 1_048_577, maximumTotalByteCount: 1_048_577,
            maximumPageCount: 100, maximumWorkUnitCount: 2_097_154, maximumDurationNanoseconds: 30_000_000_000)
        do {
            _ = try await reader.loadBudget(root: fixture.root, relativePath: ArtifactRelativePath(segments: ["budget.json"]),
                policy: PDKBudgetBootstrapPolicy(maximumByteCount: 1_048_577), accessBudget: unsupported)
            Issue.record("Unsupported native single-page capability was accepted")
        } catch let error as PDKProfileCLIInputError { #expect(error == .unsupportedSinglePageAcquisition) }
        #expect(probe.state.withLock { $0.opens } == 0)
        try Data(repeating: 32, count: 101).write(to: fixture.root.rootURL.appending(path: "budget.json"))
        let access = try ArtifactAccessBudget(maximumPageByteCount: 100, maximumTotalByteCount: 100,
            maximumPageCount: 100, maximumWorkUnitCount: 1000, maximumDurationNanoseconds: 30_000_000_000)
        do {
            _ = try await reader.loadBudget(root: fixture.root, relativePath: ArtifactRelativePath(segments: ["budget.json"]),
                policy: PDKBudgetBootstrapPolicy(maximumByteCount: 100), accessBudget: access)
            Issue.record("Oversized bootstrap file was accepted")
        } catch let error as PDKProfileCLIInputError { if case .discovery = error {} else { Issue.record("Wrong oversized file failure: \(error)") } }
        #expect(probe.state.withLock { $0.readBytes } == 0)
        #expect(probe.state.withLock { $0.shuts } == 1)
    }
    @Test func cleanupFailureBlocksAndPreservesPrimaryCancellation() async throws {
        let fixture = try await CLIInputFixture.make(); defer { fixture.remove() }
        let probe = CLIInputRootProbe(failDiscovery: true, failShutdown: true)
        let access = try ArtifactAccessBudget(maximumPageByteCount: 100, maximumTotalByteCount: 100,
            maximumPageCount: 100, maximumWorkUnitCount: 1000, maximumDurationNanoseconds: 30_000_000_000)
        do {
            _ = try await NativePDKProfileCLIInputLoader(roots: probe).loadBudget(root: fixture.root,
                relativePath: ArtifactRelativePath(segments: ["budget.json"]), policy: PDKBudgetBootstrapPolicy(maximumByteCount: 100), accessBudget: access)
            Issue.record("Failed cleanup was accepted")
        } catch let error as PDKProfileCLIInputError {
            if case .cleanup(primary: .discovery(.control(.cancelled)), cleanup: .closeFailed) = error {} else {
                Issue.record("Primary/cleanup causes were lost: \(error)")
            }
        }
        #expect(probe.state.withLock { $0.shuts } == 1)
        #expect(probe.state.withLock { $0.readBytes } == 0)
    }
    @Test func exactAvailabilityAndAuthoringRoundTripUnderOneOwner() async throws {
        let fixture = try await CLIInputFixture.make(); defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.budget); defer { resources.close() }
        let availability = try fixture.availability(resources: resources)
        let authoring = try fixture.authoring(resources: resources)
        let availabilityBytes = try JSONEncoder().encode(availability)
        let authoringBytes = try JSONEncoder().encode(authoring)
        let binding = try await fixture.write(availabilityBytes, name: "availability.json")
        let authoringBinding = try await fixture.write(authoringBytes, name: "authoring.json", descriptor: PDKProfileCLIAuthoring.artifactDescriptor)
        let baseline = try fixture.live(resources)
        var first: PDKDecodedDocument<PDKProfileCLIAvailability>? = try await NativePDKProfileCLIInputLoader()
            .loadAvailability(binding: binding, root: fixture.root, resources: resources)
        #expect(first?.value.definition == nil)
        #expect(first?.value.claim == nil)
        #expect(first?.value.manifest.reference == fixture.manifest.reference)
        #expect(first?.sourceReference == binding.reference)
        #expect(try fixture.live(resources) > baseline)
        var second = first; first = nil
        #expect(second?.sourceReference == binding.reference)
        #expect(try fixture.live(resources) > baseline)
        second = nil
        #expect(try fixture.live(resources) == baseline)
        let draft = try await NativePDKProfileCLIInputLoader().loadAuthoring(binding: authoringBinding, root: fixture.root, resources: resources)
        #expect(draft.value.profileID == authoring.profileID)
        #expect(draft.value.candidateSources.first?.descriptor == authoring.candidateSources.first?.descriptor)
        #expect(draft.value.requirements == authoring.requirements)
        #expect(draft.sourceReference == authoringBinding.reference)
    }
    @Test func unknownDuplicateObsoleteAndMissingNullableFieldsFail() async throws {
        let fixture = try await CLIInputFixture.make(); defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: fixture.budget); defer { resources.close() }
        let valid = try JSONEncoder().encode(fixture.availability(resources: resources))
        let text = String(decoding: valid, as: UTF8.self)
        let variants = ["{\"unexpected\":0," + text.dropFirst(), "{\"schemaVersion\":1," + text.dropFirst(),
            text.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":9"),
            text.replacingOccurrences(of: "\"claim\":null,", with: "").replacingOccurrences(of: ",\"claim\":null", with: "")]
        for (index, value) in variants.enumerated() {
            let binding = try await fixture.write(Data(value.utf8), name: "invalid-\(index).json")
            do {
                _ = try await NativePDKProfileCLIInputLoader().loadAvailability(binding: binding, root: fixture.root, resources: resources)
                Issue.record("Invalid schema was accepted at variant \(index)")
            } catch { if case .decode = error {} else { Issue.record("Invalid wire escaped typed decode: \(error)") } }
        }
    }
    @Test func sourceDriftAndCumulativeReadLimitCannotResetBetweenDocuments() async throws {
        let fixture = try await CLIInputFixture.make(); defer { fixture.remove() }
        let prepared = LocalPDKAdmissionResources(budget: fixture.budget); defer { prepared.close() }
        let bytes = try JSONEncoder().encode(fixture.availability(resources: prepared))
        let first = try await fixture.write(bytes, name: "first.json")
        let second = try await fixture.write(bytes, name: "second.json")
        var limits = fixture.budget.limits; limits[.readBytes] = UInt64(bytes.count * 2 - 1)
        let budget = try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: 30_000_000_000)
        let resources = LocalPDKAdmissionResources(budget: budget); defer { resources.close() }
        let retained = try await NativePDKProfileCLIInputLoader().loadAvailability(binding: first, root: fixture.root, resources: resources)
        defer { withExtendedLifetime(retained) {} }
        do {
            _ = try await NativePDKProfileCLIInputLoader().loadAvailability(binding: second, root: fixture.root, resources: resources)
            Issue.record("Second input reset the shared read budget")
        } catch { if case .source(.resource(.exhausted(dimension: .readBytes, limit: _, attempted: _))) = error {} else { Issue.record("Wrong cumulative refusal: \(error)") } }
        try Data("changed".utf8).write(to: fixture.root.rootURL.appending(path: "first.json"))
        let fresh = LocalPDKAdmissionResources(budget: fixture.budget); defer { fresh.close() }
        do {
            _ = try await NativePDKProfileCLIInputLoader().loadAvailability(binding: first, root: fixture.root, resources: fresh)
            Issue.record("Changed availability input was accepted")
        } catch { if case .source = error {} else { Issue.record("Wrong drift refusal: \(error)") } }
    }
}
