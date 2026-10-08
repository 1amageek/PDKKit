import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation
import PDKCore
@testable import PDKDiscovery
import PDKSourceCapture
import Testing

@Suite(.timeLimit(.minutes(1)))
struct BoundedCandidateDiscoveryTests {
    private struct Fixture {
        let roots: [PDKBoundedDiscoveryRoot]
        let bytes: [Data]
        let descriptor: ArtifactDescriptor
        init(extraCandidate: Bool = false, malformed: Bool = false) throws {
            descriptor = try ArtifactDescriptor(role: .output, kind: ArtifactKind(rawValue: "pdk.technology"), format: .json)
            var checked: [PDKBoundedDiscoveryRoot] = [], inputs: [Data] = []
            for process in ["p", "q"] {
                let url = FileManager.default.temporaryDirectory.appending(path: "pdk-candidate-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                let data = try PDKManifestCodec.encode(PDKManifest(processID: process, version: "1"))
                try (malformed && process == "q" ? Data("{".utf8) : data).write(to: url.appending(path: "pdk.json"))
                let inventory = try ArtifactDirectoryInventoryIntent(rootID: ArtifactRootID(rawValue: UUID().uuidString),
                    maximumVisitedEntryCount: 100, maximumDepth: 10, maximumResultCount: 100,
                    maximumWorkUnitCount: 100_000, maximumDurationNanoseconds: 10_000_000_000)
                checked.append(try PDKBoundedDiscoveryRoot(rootURL: url, inventory: inventory,
                    sourceBudget: ArtifactAccessBudget(maximumPageByteCount: 4096, maximumTotalByteCount: 1_000_000,
                        maximumPageCount: 1000, maximumWorkUnitCount: 1_000_000,
                        maximumDurationNanoseconds: 10_000_000_000)))
                inputs.append(data)
            }
            if extraCandidate {
                let nested = checked[0].rootURL.appending(path: "nested")
                try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
                try inputs[0].write(to: nested.appending(path: "pdk.json"))
            }
            roots = checked; bytes = inputs
        }
        func cleanup() {
            for root in roots {
                do { try FileManager.default.removeItem(at: root.rootURL) }
                catch { Issue.record("Fixture cleanup failed: \(error)") }
            }
        }
        func discover(_ resources: ManifestLoadTestAccounting, processID: String? = nil,
                      loader: any PDKBoundedManifestLoading = LocalPDKBoundedManifestLoader())
            async throws -> PDKBoundedDiscoveryResult {
            try await LocalPDKBoundedDiscoverer(loader: loader).discover(roots: roots, descriptor: descriptor,
                processID: processID, resources: resources)
        }
    }
    private struct AfterLoad: PDKBoundedManifestLoading {
        enum Action: Sendable { case fail(PDKAdmissionResourceError), denyCollectionCapacity }
        let accounting: ManifestLoadTestAccounting
        let action: Action
        func discover(descriptor: ArtifactDescriptor, rootURL: URL, rootID: ArtifactRootID,
                      relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                      resources: any PDKAdmissionResourceAccounting)
            async throws(PDKBoundedManifestLoadingError) -> PDKBoundedLoadedManifest {
            let loaded = try await LocalPDKBoundedManifestLoader().discover(descriptor: descriptor,
                rootURL: rootURL, rootID: rootID, relativePath: relativePath, budget: budget, resources: resources)
            switch action {
            case .fail(let error): accounting.failure = error
            case .denyCollectionCapacity: accounting.limit(.liveOwnedBytes, to: accounting.used(.liveOwnedBytes))
            }
            return loaded
        }
        func loadExact(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                       relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                       resources: any PDKAdmissionResourceAccounting)
            async throws(PDKBoundedManifestLoadingError) -> PDKBoundedLoadedManifest {
            try await LocalPDKBoundedManifestLoader().loadExact(reference: reference,
                rootURL: rootURL, rootID: rootID, relativePath: relativePath, budget: budget, resources: resources)
        }
    }
    @Test func filteringUsesTheRetainedSourceAndKeepsDuplicateProcesses() async throws {
        let fixture = try Fixture(extraCandidate: true); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        let result = try await fixture.discover(resources, processID: "p")
        #expect(result.progress.completedRootCount == 2)
        #expect(result.progress.observedCandidateCount == 3)
        #expect(result.candidates.count == 2)
        try FileManager.default.removeItem(at: fixture.roots[0].rootURL.appending(path: "pdk.json"))
        for candidate in result.candidates {
            #expect(candidate.loaded.manifest.processID == "p")
            #expect(candidate.root.inventory.rootID == fixture.roots[0].inventory.rootID)
            #expect(candidate.entry.kind == .regularFile)
            let expected = fixture.bytes[0]
            candidate.loaded.source.withBytes { span in
                #expect(span.count == expected.count)
                for index in 0..<span.count { #expect(span[index] == expected[index]) }
            }
        }
        #expect(resources.used(.searchRoots) == 2)
        #expect(resources.used(.candidates) == 3)
        #expect(resources.used(.openResources) == 0)
    }
    @Test(arguments: [PDKAdmissionResourceDimension.searchRoots, .candidates, .readBytes, .decodedElements])
    func cumulativeLimitsAbortTheWholeSearch(dimension: PDKAdmissionResourceDimension) async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let probe = ManifestLoadTestAccounting()
        var measured: PDKBoundedDiscoveryResult? = try await fixture.discover(probe)
        #expect(measured?.candidates.count == 2)
        let full = probe.used(dimension)
        measured = nil
        let resources = ManifestLoadTestAccounting(); resources.limit(dimension, to: full - 1)
        do {
            _ = try await fixture.discover(resources)
            Issue.record("A cumulative quota returned a completed search")
        } catch let error as PDKBoundedDiscoveryError {
            guard case .incomplete(let progress, let failure) = error else { return }
            #expect(progress.completedRootCount == 1)
            switch (dimension, failure) {
            case (.searchRoots, .resource(.exhausted(let actual, _, _))),
                 (.candidates, .resource(.exhausted(let actual, _, _))),
                 (.readBytes, .manifest(.source(.resource(.exhausted(let actual, _, _))))),
                 (.decodedElements, .manifest(.decode(.resource(.exhausted(let actual, _, _))))):
                #expect(actual == dimension)
            default: Issue.record("Unexpected quota failure: \(error)")
            }
        }
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.openResources) == 0)
        #expect(resources.used(.concurrentAcquisitions) == 0)
    }
    @Test func symlinkEntriesAndOtherNamesAreNeverCandidateSources() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let first = fixture.roots[0].rootURL
        try FileManager.default.removeItem(at: first.appending(path: "pdk.json"))
        try FileManager.default.createSymbolicLink(at: first.appending(path: "pdk.json"),
            withDestinationURL: fixture.roots[1].rootURL.appending(path: "pdk.json"))
        try fixture.bytes[0].write(to: first.appending(path: "manifest.json"))
        let resources = ManifestLoadTestAccounting()
        let result = try await fixture.discover(resources)
        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].loaded.manifest.processID == "q")
        #expect(resources.used(.candidates) == 1)
        #expect(resources.used(.readBytes) == UInt64(fixture.bytes[1].count))
    }
    @Test func formatAndMalformedInputRemainTypedIncompleteFailures() async throws {
        let fixture = try Fixture(malformed: true); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        let wrong = try ArtifactDescriptor(role: .output, kind: fixture.descriptor.kind, format: .text)
        do {
            _ = try await LocalPDKBoundedDiscoverer().discover(roots: fixture.roots, descriptor: wrong,
                processID: nil, resources: resources)
            Issue.record("Unsupported format was searched")
        } catch let error as PDKBoundedDiscoveryError {
            #expect(error == .incomplete(progress: .init(completedRootCount: 0, observedCandidateCount: 0), failure: .invalidFormat))
        }
        #expect(resources.used(.searchRoots) == 0)
        do {
            _ = try await fixture.discover(resources)
            Issue.record("Malformed candidate was reduced to a complete search")
        } catch let error as PDKBoundedDiscoveryError {
            guard case .incomplete(let progress, .manifest(.decode(.malformed))) = error else {
                Issue.record("Unexpected malformed failure: \(error)"); return
            }
            #expect(progress.completedRootCount == 1)
            #expect(progress.observedCandidateCount == 2)
        }
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.openResources) == 0)
    }
    @Test(arguments: [PDKAdmissionResourceError.cancelled, .deadlineExceeded])
    func cancellationOrDeadlineAfterLoadStopsLaterRootsAndRefusesPublication(failure: PDKAdmissionResourceError) async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        do {
            _ = try await fixture.discover(resources, loader: AfterLoad(accounting: resources, action: .fail(failure)))
            Issue.record("A cancelled candidate search was published")
        } catch let error as PDKBoundedDiscoveryError {
            #expect(error == .incomplete(progress: .init(completedRootCount: 0, observedCandidateCount: 1), failure: .resource(failure)))
        }
        #expect(resources.used(.searchRoots) == 1)
        #expect(resources.used(.readBytes) == UInt64(fixture.bytes[0].count))
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.openResources) == 0)
    }
    @Test func outputCapacityIsReservedBeforeItsFirstAllocation() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        do {
            _ = try await fixture.discover(resources, loader: AfterLoad(accounting: resources, action: .denyCollectionCapacity))
            Issue.record("Output allocation bypassed admission")
        } catch let error as PDKBoundedDiscoveryError {
            guard case .incomplete(_, .resource(.exhausted(let dimension, let limit, let attempted))) = error else {
                Issue.record("Unexpected output-capacity failure: \(error)"); return
            }
            #expect(dimension == .liveOwnedBytes)
            #expect(attempted - limit == UInt64(MemoryLayout<PDKBoundedCandidate?>.stride))
        }
        #expect(resources.used(.searchRoots) == 1)
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
    }
    @Test func grownResultsAndEscapedCandidatesRetainOnlyTheirLatestSnapshot() async throws {
        let fixture = try Fixture(extraCandidate: true); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        var result: PDKBoundedDiscoveryResult? = try await fixture.discover(resources)
        var resultCopy = result
        #expect(result?.candidates.managedCapacity == 4)
        let capacity = UInt64(4 * MemoryLayout<PDKBoundedCandidate?>.stride)
        for candidate in result!.candidates { #expect(candidate.collectionLease.cost.amount == capacity) }
        var candidate: PDKBoundedCandidate? = result?.candidates[0]
        var candidateCopy = candidate
        let held = resources.used(.liveOwnedBytes)
        result = nil
        #expect(resources.used(.liveOwnedBytes) == held)
        #expect(resultCopy?.candidates.count == 3)
        resultCopy = nil
        let escaped = resources.used(.liveOwnedBytes)
        #expect(escaped >= capacity)
        #expect(escaped < held)
        candidate = nil
        #expect(resources.used(.liveOwnedBytes) == escaped)
        #expect(candidateCopy?.loaded.manifest.processID == "p")
        candidateCopy = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
        #expect(resources.used(.temporaryBytes) == 0)
        #expect(resources.used(.openResources) == 0)
    }
    @Test func ambiguousRootBindingsAreRejectedBeforeEnumeration() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = ManifestLoadTestAccounting()
        let duplicateID = try PDKBoundedDiscoveryRoot(rootURL: fixture.roots[1].rootURL,
            inventory: fixture.roots[0].inventory, sourceBudget: fixture.roots[0].sourceBudget)
        let duplicateURL = try PDKBoundedDiscoveryRoot(rootURL: fixture.roots[0].rootURL,
            inventory: fixture.roots[1].inventory, sourceBudget: fixture.roots[0].sourceBudget)
        for (root, reason) in [(duplicateID, PDKBoundedDiscoveryFailure.duplicateRootID), (duplicateURL, .duplicateRootURL)] {
            do {
                _ = try await LocalPDKBoundedDiscoverer().discover(roots: [fixture.roots[0], root],
                    descriptor: fixture.descriptor, processID: nil, resources: resources)
                Issue.record("Ambiguous root authority was silently replaced")
            } catch let error as PDKBoundedDiscoveryError {
                #expect(error == .incomplete(progress: .init(completedRootCount: 0, observedCandidateCount: 0), failure: reason))
            }
        }
        #expect(resources.used(.searchRoots) == 0)
        #expect(resources.used(.openResources) == 0)
    }
}
