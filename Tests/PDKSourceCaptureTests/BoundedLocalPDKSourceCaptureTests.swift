import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation
import PDKCore
@testable import PDKSourceCapture
import Testing

@Suite(.timeLimit(.minutes(1))) struct BoundedLocalPDKSourceCaptureTests {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func cleanup(_ url: URL) {
        do { try FileManager.default.removeItem(at: url) } catch { Issue.record("Root cleanup failed: \(error)") }
    }
    private func rootID() throws -> ArtifactRootID { try ArtifactRootID(rawValue: "bounded-capture") }
    private func path(_ name: String) throws -> ArtifactRelativePath { try ArtifactRelativePath(segments: [name]) }

    @Test func twoSourcesShareCumulativeReadQuotaAndLastCopyRetention() async throws {
        let url = try root(); defer { cleanup(url) }
        try Data([1, 2, 3, 4]).write(to: url.appendingPathComponent("a"))
        try Data([5, 6, 7, 8]).write(to: url.appendingPathComponent("b"))
        try Data([9]).write(to: url.appendingPathComponent("c"))
        let accounting = BoundedCaptureTestAccounting(); accounting.limit(.readBytes, to: 8)
        let digester = BoundedCaptureTestDigester()
        let service = LocalPDKBoundedSourceCapturer(digester: digester)
        var last: CapturedPDKSource?
        do {
            let first = try await service.capture(reference: captureReference([1, 2, 3, 4]), rootURL: url,
                rootID: rootID(), relativePath: path("a"), budget: captureBudget(), resources: accounting)
            let second = try await service.capture(reference: captureReference([5, 6, 7, 8]), rootURL: url,
                rootID: rootID(), relativePath: path("b"), budget: captureBudget(), resources: accounting)
            last = first
            #expect(first.withBytes { $0.count } == 4)
            #expect(second.withBytes { $0.count } == 4)
            #expect(accounting.used(.readBytes) == 8)
            #expect(accounting.used(.hashedBytes) == 16)
            #expect(accounting.used(.liveOwnedBytes) == 8)
            #expect(throws: PDKSourceCaptureError.self) { try first.data(maximumByteCount: 4) }
        }
        #expect(accounting.used(.liveOwnedBytes) == 4)
        #expect(last?.byteCount == 4)
        last = nil
        #expect(accounting.used(.liveOwnedBytes) == 0)
        await #expect(throws: PDKSourceCaptureError.resource(.exhausted(dimension: .readBytes, limit: 8, attempted: 9))) {
            try await service.discover(descriptor: captureReference([9]).descriptor, rootURL: url,
                rootID: rootID(), relativePath: path("c"), budget: captureBudget(), resources: accounting)
        }
        #expect(digester.count == 4)
        #expect(accounting.used(.temporaryBytes) == 0)
        #expect(accounting.used(.openResources) == 0)
        #expect(accounting.used(.concurrentAcquisitions) == 0)
    }

    @Test func copyCapacityFailurePrecedesSecondDigestAndReleasesObservedPages() async throws {
        let url = try root(); defer { cleanup(url) }
        try Data([1, 2, 3, 4]).write(to: url.appendingPathComponent("a"))
        let accounting = BoundedCaptureTestAccounting()
        // Foundation's one-page managed contract: payload, page slot, retention slot,
        // plus the container retention slot. The independent capture copy needs 4 more.
        let container = MemoryLayout<[UInt8]>.stride + MemoryLayout<any ArtifactSourceRetention>.stride + MemoryLayout<any ArtifactSourceRetention>.stride
        let observedExtent = UInt64(container) + 4
        accounting.limit(.liveOwnedBytes, to: observedExtent)
        let digester = BoundedCaptureTestDigester()
        await #expect(throws: PDKSourceCaptureError.resource(.exhausted(dimension: .liveOwnedBytes, limit: observedExtent, attempted: observedExtent + 4))) {
            try await LocalPDKBoundedSourceCapturer(digester: digester).discover(descriptor: captureReference([1, 2, 3, 4]).descriptor,
                rootURL: url, rootID: rootID(), relativePath: path("a"), budget: captureBudget(), resources: accounting)
        }
        #expect(digester.count == 1)
        #expect(accounting.used(.liveOwnedBytes) == 0)
        #expect(accounting.used(.openResources) == 0)
    }

    @Test func exactReferenceRejectsTamperAndDescriptorSubstitution() async throws {
        let url = try root(); defer { cleanup(url) }
        let expected = try captureReference([1, 2, 3, 4])
        try Data([4, 3, 2, 1]).write(to: url.appendingPathComponent("a"))
        let accounting = BoundedCaptureTestAccounting()
        await #expect(throws: PDKSourceCaptureError.self) {
            try await LocalPDKBoundedSourceCapturer().capture(reference: expected, rootURL: url,
                rootID: rootID(), relativePath: path("a"), budget: captureBudget(), resources: accounting)
        }
        try Data([1, 2, 3, 4]).write(to: url.appendingPathComponent("a"))
        let altered = ArtifactDescriptor(role: .output, kind: .report, format: .json)
        let roots = BoundedCaptureTestRootOpener(accounting: accounting, replacementDescriptor: altered)
        await #expect(throws: PDKSourceCaptureError.receiptMismatch) {
            try await LocalPDKBoundedSourceCapturer(roots: roots).capture(reference: expected, rootURL: url,
                rootID: rootID(), relativePath: path("a"), budget: captureBudget(), resources: accounting)
        }
        #expect(roots.shutdownCount == 1)
        #expect(accounting.used(.liveOwnedBytes) == 0)
    }

    @Test func rootAdmissionPrecedesOpenAndLateTerminalStatesRefusePublication() async throws {
        let url = try root(); defer { cleanup(url) }
        try Data([1]).write(to: url.appendingPathComponent("a"))
        let refused = BoundedCaptureTestAccounting(); refused.limit(.openResources, to: 0)
        let roots = BoundedCaptureTestRootOpener(accounting: refused)
        await #expect(throws: PDKSourceCaptureError.resource(.exhausted(dimension: .openResources, limit: 0, attempted: 1))) {
            try await LocalPDKBoundedSourceCapturer(roots: roots).discover(descriptor: captureReference([1]).descriptor,
                rootURL: url, rootID: rootID(), relativePath: path("a"), budget: captureBudget(), resources: refused)
        }
        #expect(roots.openCount == 0)
        for error in [PDKAdmissionResourceError.cancelled, .deadlineExceeded] {
            let accounting = BoundedCaptureTestAccounting()
            let roots = BoundedCaptureTestRootOpener(accounting: accounting, lateFailure: error)
            await #expect(throws: PDKSourceCaptureError.resource(error)) {
                try await LocalPDKBoundedSourceCapturer(roots: roots).discover(descriptor: captureReference([1]).descriptor,
                    rootURL: url, rootID: rootID(), relativePath: path("a"), budget: captureBudget(), resources: accounting)
            }
            #expect(roots.shutdownCount == 1)
            #expect(accounting.used(.liveOwnedBytes) == 0)
            #expect(accounting.used(.openResources) == 0)
        }
    }

    @Test func primaryAndRootCleanupFailureRemainDistinct() async throws {
        let url = try root(); defer { cleanup(url) }
        try Data([1]).write(to: url.appendingPathComponent("a"))
        let accounting = BoundedCaptureTestAccounting(); accounting.limit(.readBytes, to: 0)
        let roots = BoundedCaptureTestRootOpener(accounting: accounting, closeFailure: true)
        await #expect(throws: PDKSourceCaptureError.cleanup(
            primary: .resource(.exhausted(dimension: .readBytes, limit: 0, attempted: 1)),
            cleanup: .root(.closeFailed(reason: "injected root close")))) {
            try await LocalPDKBoundedSourceCapturer(roots: roots).discover(descriptor: captureReference([1]).descriptor,
                rootURL: url, rootID: rootID(), relativePath: path("a"), budget: captureBudget(), resources: accounting)
        }
        #expect(roots.shutdownCount == 1)
        #expect(accounting.used(.openResources) == 0)
    }

    @Test func multiPageCaptureStaysOwnedAfterDeletionAndChunkLimitsAreCharged() async throws {
        let url = try root(); defer { cleanup(url) }
        let bytes = Array(0..<UInt8(12))
        try Data(bytes).write(to: url.appendingPathComponent("a"))
        let accounting = BoundedCaptureTestAccounting()
        let source = try await LocalPDKBoundedSourceCapturer().capture(reference: captureReference(bytes), rootURL: url,
            rootID: rootID(), relativePath: path("a"), budget: captureBudget(), resources: accounting)
        try FileManager.default.removeItem(at: url.appendingPathComponent("a"))
        source.withBytes { span in
            #expect(span.count == bytes.count)
            for index in 0..<span.count { #expect(span[index] == bytes[index]) }
        }
        #expect(accounting.used(.pages) == 3)
        #expect(accounting.used(.hashedBytes) == 24)
        #expect(accounting.used(.liveOwnedBytes) == 12)
        #expect(accounting.peak(.temporaryBytes) == 12)
        #expect(accounting.used(.temporaryBytes) == 0)
    }

    @Test func controlledEnumerationHasSharedQuotaCopiedEntryLifetimeAndCancellation() async throws {
        let url = try root(); defer { cleanup(url) }
        try Data([1]).write(to: url.appendingPathComponent("a"))
        try Data([2]).write(to: url.appendingPathComponent("b"))
        let intent = try ArtifactDirectoryInventoryIntent(rootID: rootID(), maximumVisitedEntryCount: 16,
            maximumDepth: 2, maximumResultCount: 4, maximumWorkUnitCount: 64, maximumDurationNanoseconds: 5_000_000_000)
        let accounting = BoundedCaptureTestAccounting()
        var entries: [ArtifactDirectoryEntry] = []
        do {
            let inventory = try await LocalPDKBoundedSourceCapturer().enumerate(intent: intent, rootURL: url, resources: accounting)
            entries = inventory.entries
            #expect(entries.count == 2)
            #expect(accounting.used(.scannedEntries) == 4)
            #expect(accounting.used(.openResources) == 0)
        }
        #expect(accounting.used(.liveOwnedBytes) > 0)
        withExtendedLifetime(entries) {}
        entries = []
        #expect(accounting.used(.liveOwnedBytes) == 0)
        let refused = BoundedCaptureTestAccounting(); refused.limit(.scannedEntries, to: 1)
        await #expect(throws: PDKSourceCaptureError.resource(.exhausted(dimension: .scannedEntries, limit: 1, attempted: 2))) {
            try await LocalPDKBoundedSourceCapturer().enumerate(intent: intent, rootURL: url, resources: refused)
        }
        #expect(refused.used(.openResources) == 0)
        let cancelled = BoundedCaptureTestAccounting()
        let roots = BoundedCaptureTestRootOpener(accounting: cancelled, lateFailure: .cancelled)
        await #expect(throws: PDKSourceCaptureError.resource(.cancelled)) {
            try await LocalPDKBoundedSourceCapturer(roots: roots).enumerate(intent: intent, rootURL: url, resources: cancelled)
        }
        #expect(roots.shutdownCount == 1)
        #expect(cancelled.used(.liveOwnedBytes) == 0)
    }

    @Test func resourceBridgePreservesAllEightDimensionsAndOriginalErrorCodes() throws {
        let pairs: [(ArtifactSourceResource, PDKAdmissionResourceDimension)] = [
            (.readBytes, .readBytes), (.hashedBytes, .hashedBytes), (.pages, .pages), (.workUnits, .parserWork),
            (.visitedEntries, .scannedEntries), (.ownedBytes, .liveOwnedBytes), (.temporaryBytes, .temporaryBytes), (.openResources, .openResources)]
        for (generic, pdk) in pairs {
            let bridge = PDKSourceResourceControl(resources: BoundedCaptureTestAccounting())
            #expect(bridge.sourceError(.control(.quotaExceeded(resource: generic, limit: 1, attempted: 2))) == .resource(.exhausted(dimension: pdk, limit: 1, attempted: 2)))
            #expect(bridge.sourceError(.control(.arithmeticOverflow(resource: generic))) == .resource(.arithmeticOverflow(pdk)))
        }
        for failure in [PDKAdmissionResourceError.cancelled, .deadlineExceeded, .closed, .invalidCost, .unsupportedAccountingVersion(42)] {
            let accounting = BoundedCaptureTestAccounting(); accounting.failure = failure
            let bridge = PDKSourceResourceControl(resources: accounting)
            do { try bridge.check(); Issue.record("Bridge accepted terminal state") }
            catch { #expect(bridge.sourceError(.control(error)) == .resource(failure)) }
        }
    }
}
