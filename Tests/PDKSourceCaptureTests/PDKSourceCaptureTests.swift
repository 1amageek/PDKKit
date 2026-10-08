import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import PDKSourceCapture
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PDKSourceCaptureTests {
    @Test
    func classificationPreservesIntegrityAndCleanupDistinctions() throws {
        let expected = try captureReference([97]).digest
        let actual = try captureReference([98]).digest
        #expect(PDKSourceCaptureError.access(.contentDigestMismatch(expected: expected, actual: actual)).classification == .digestMismatch)
        #expect(PDKSourceCaptureError.access(.byteCountMismatch(expected: 1, actual: 2)).classification == .byteCountMismatch)
        #expect(PDKSourceCaptureError.access(.cancelled).classification == .cancellation)
        let combined = PDKSourceCaptureError.cleanup(
            primary: .access(.contentDigestMismatch(expected: expected, actual: actual)),
            cleanup: .sessionCleanup(.cleanupFailed(reason: "close"))
        )
        #expect(combined.classification == .cleanup(primary: .digestMismatch, failure: .cleanup(primary: nil, failure: .other)))
        #expect(PDKSourceCaptureError.cleanup(primary: .cancelled, cleanup: .invalidTermination).classification == .cleanup(primary: .cancellation, failure: .cleanup(primary: nil, failure: .other)))
    }

    @Test
    func multipleSequentialPagesAndEmptySourceAreAdmitted() async throws {
        let reference = try captureReference([97, 98, 99, 100])
        let pages = [
            try capturePage(reference, bytes: [97, 98], terminal: false),
            try capturePage(reference, bytes: [99, 100], offset: 2, pageCount: 2, workUnits: 2, elapsed: 2)
        ]
        let session = try CaptureTestSession(reference: reference, pages: pages)
        let captured = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester())
            .capture(captureIntent(reference))
        #expect(try captured.data(maximumByteCount: 4) == Data([97, 98, 99, 100]))
        #expect(await session.readCount == 2)
        let emptyReference = try captureReference([])
        let emptySession = try CaptureTestSession(reference: emptyReference, pages: [capturePage(emptyReference, bytes: [])])
        let empty = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: emptySession), digester: SHA256ContentDigester())
            .capture(captureIntent(emptyReference))
        #expect(empty.byteCount == 0)
        #expect(try empty.data(maximumByteCount: 0).isEmpty)
    }

    @Test
    func actualOwnedBytesAreVerifiedAndExposed() async throws {
        let bytes = Array("abcd".utf8)
        let reference = try captureReference(bytes)
        let session = try CaptureTestSession(reference: reference, pages: [capturePage(reference, bytes: bytes)])
        let result = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester())
            .capture(captureIntent(reference))
        #expect(result.reference == reference)
        #expect(result.withBytes { $0.count } == bytes.count)
        #expect(try result.data(maximumByteCount: 64) == Data(bytes))
        #expect(await session.closeCount == 1)
        #expect(await session.termination.waitCount == 1)
        #expect(throws: PDKSourceCaptureError.byteLimitExceeded(limit: 1, actual: 4)) {
            try result.data(maximumByteCount: 1)
        }
    }

    @Test
    func falseReceiptDoesNotAdmitDifferentSameLengthBytes() async throws {
        let reference = try captureReference(Array("abcd".utf8))
        let falseBytes = Array("fake".utf8)
        let session = try CaptureTestSession(reference: reference, pages: [capturePage(reference, bytes: falseBytes)])
        do {
            _ = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester())
                .capture(captureIntent(reference))
            Issue.record("Forged receipt admitted different bytes.")
        } catch let error as PDKSourceCaptureError {
            guard case .digestMismatch = error else { Issue.record("Unexpected error: \(error)"); return }
        } catch {
            Issue.record("Unexpected setup error: \(error)")
        }
        #expect(await session.closeCount == 1)
        #expect(await session.termination.waitCount == 1)
    }

    @Test(arguments: ["truncated", "offset", "empty", "cumulative", "work", "time", "oversized", "owner-count", "receipt-work"])
    func malformedPagesAreRejected(_ variant: String) async throws {
        let bytes = Array("abcd".utf8)
        let reference = try captureReference(bytes)
        let page: ArtifactReadPage
        switch variant {
        case "truncated":
            page = try capturePage(reference, bytes: [97, 98], terminal: true)
        case "offset":
            page = try capturePage(reference, bytes: [97], offset: 1, terminal: false)
        case "empty":
            page = try capturePage(reference, bytes: [], terminal: false)
        case "cumulative":
            page = try capturePage(reference, bytes: bytes, cumulative: 5)
        case "work":
            page = try capturePage(reference, bytes: bytes, workUnits: 100)
        case "time":
            page = try capturePage(reference, bytes: bytes, elapsed: 10_000_000_000)
        case "oversized":
            page = try capturePage(reference, bytes: bytes + [101])
        case "owner-count":
            page = try capturePage(reference, bytes: [97, 98], claimedCount: 4)
        default:
            page = try capturePage(reference, bytes: bytes, receiptWorkUnits: 100)
        }
        let session = try CaptureTestSession(reference: reference, pages: [page])
        await #expect(throws: PDKSourceCaptureError.self) {
            _ = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester())
                .capture(captureIntent(reference))
        }
        #expect(await session.closeCount == 1)
        #expect(await session.termination.waitCount == 1)
    }

    @Test
    func pageCountAndWorkLimitsApplyToTheActualCapture() async throws {
        let reference = try captureReference([97, 98])
        let pages = [
            try capturePage(reference, bytes: [97], terminal: false),
            try capturePage(reference, bytes: [98], offset: 1, pageCount: 2, workUnits: 2)
        ]
        let session = try CaptureTestSession(reference: reference, pages: pages)
        let budget = try captureBudget(pages: 1)
        await #expect(throws: PDKSourceCaptureError.pageLimitExceeded(limit: 1)) {
            _ = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester())
                .capture(captureIntent(reference, budget: budget))
        }
        #expect(await session.readCount == 1)
        #expect(await session.closeCount == 1)
    }

    @Test
    func expectedSizeIsRejectedBeforeOpeningOrAllocation() async throws {
        let reference = try captureReference(Array("abcd".utf8))
        let session = try CaptureTestSession(reference: reference, pages: [])
        let access = CaptureTestAccess(session: session)
        await #expect(throws: PDKSourceCaptureError.byteLimitExceeded(limit: 2, actual: 4)) {
            _ = try await StandardPDKSourceCapturer(access: access, digester: SHA256ContentDigester())
                .capture(captureIntent(reference, budget: captureBudget(total: 2)))
        }
        #expect(await access.openCount == 0)
    }

    @Test
    func cleanupFailurePreventsPublication() async throws {
        let reference = try captureReference([97])
        let session = try CaptureTestSession(reference: reference, pages: [capturePage(reference, bytes: [97])], closeFailure: true)
        await #expect(throws: PDKSourceCaptureError.sessionCleanup(.cleanupFailed(reason: "injected close"))) {
            _ = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester())
                .capture(captureIntent(reference))
        }
        #expect(await session.termination.waitCount == 1)
    }

    @Test
    func primaryAndCleanupFailureAreBothPreserved() async throws {
        let reference = try captureReference([97])
        let session = try CaptureTestSession(reference: reference, pages: [], readFailure: .truncatedResource, closeFailure: true)
        await #expect(throws: PDKSourceCaptureError.cleanup(
            primary: .access(.truncatedResource),
            cleanup: .sessionCleanup(.cleanupFailed(reason: "injected close"))
        )) {
            _ = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester())
                .capture(captureIntent(reference))
        }
    }

    @Test
    func cancellationAfterReadStillWaitsForCleanup() async throws {
        let reference = try captureReference([97])
        let session = try CaptureTestSession(reference: reference, pages: [capturePage(reference, bytes: [97])], cancelOnRead: true)
        let intent = try captureIntent(reference)
        let task = Task {
            try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester()).capture(intent)
        }
        await #expect(throws: PDKSourceCaptureError.cancelled) { try await task.value }
        #expect(await session.closeCount == 1)
        #expect(await session.termination.waitCount == 1)
    }

    @Test
    func missingTerminalTerminationIsRejected() async throws {
        let reference = try captureReference([97])
        let session = try CaptureTestSession(reference: reference, pages: [capturePage(reference, bytes: [97])], terminalClose: false)
        await #expect(throws: PDKSourceCaptureError.invalidTermination) {
            _ = try await StandardPDKSourceCapturer(access: CaptureTestAccess(session: session), digester: SHA256ContentDigester())
                .capture(captureIntent(reference))
        }
    }
}
