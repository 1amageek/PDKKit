import CircuiteFoundation

public struct StandardPDKSourceCapturer: PDKSourceCapturing {
    private let access: any ArtifactAccessing
    private let digester: any ContentDigesting

    public init(access: any ArtifactAccessing, digester: any ContentDigesting) {
        self.access = access
        self.digester = digester
    }

    public func capture(
        _ intent: ArtifactAccessIntent
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        let started = ContinuousClock.now
        try Self.checkDeadline(started, budget: intent.budget)
        guard intent.expectedReference.byteCount <= intent.budget.maximumTotalByteCount,
              intent.expectedReference.byteCount <= UInt64(Int.max) else {
            throw .byteLimitExceeded(
                limit: min(intent.budget.maximumTotalByteCount, UInt64(Int.max)),
                actual: intent.expectedReference.byteCount
            )
        }
        let session: any ArtifactReadSession
        do { session = try await access.open(intent) }
        catch { throw error == .cancelled ? .cancelled : .access(error) }

        let result: Result<CapturedPDKSource, PDKSourceCaptureError>
        do throws(PDKSourceCaptureError) {
            guard session.expectedReference == intent.expectedReference else {
                throw PDKSourceCaptureError.receiptMismatch
            }
            result = .success(try await accumulate(session, intent: intent, started: started))
        } catch { result = .failure(error) }

        let termination = await session.close()
        do {
            let receipt = try await termination.wait()
            guard termination.sessionIdentity == session.identity,
                  receipt.sessionIdentity == session.identity else {
                throw PDKSourceCaptureError.invalidTermination
            }
            if case .success = result, !receipt.didReachTerminalPage {
                throw PDKSourceCaptureError.invalidTermination
            }
        } catch {
            let cleanup: PDKSourceCaptureError
            if let typed = error as? PDKSourceCaptureError { cleanup = typed }
            else if let typed = error as? ArtifactAccessTerminationError { cleanup = .sessionCleanup(typed) }
            else { cleanup = .invalidTermination }
            switch result {
            case .failure(let primary): throw .cleanup(primary: primary, cleanup: cleanup)
            case .success: throw cleanup
            }
        }
        switch result {
        case .failure(let error): throw error
        case .success(let captured):
            try Self.checkDeadline(started, budget: intent.budget)
            return captured
        }
    }

    private func accumulate(
        _ session: any ArtifactReadSession,
        intent: ArtifactAccessIntent,
        started: ContinuousClock.Instant
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        let budget = intent.budget
        try Self.checkDeadline(started, budget: budget)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(Int(intent.expectedReference.byteCount))
        var pageCount: UInt64 = 0
        var previousWork = ArtifactAccessWorkReport(pageCount: 0, workUnitCount: 0, elapsedNanoseconds: 0)
        while true {
            try Self.checkDeadline(started, budget: budget)
            guard pageCount < budget.maximumPageCount else {
                throw .pageLimitExceeded(limit: budget.maximumPageCount)
            }
            let offset = UInt64(bytes.count)
            let request: ArtifactReadPageRequest
            do { request = try ArtifactReadPageRequest(offset: offset, maximumByteCount: budget.maximumPageByteCount) }
            catch { throw .invalidPage(reason: String(describing: error)) }
            let page: ArtifactReadPage
            do { page = try await session.readPage(request) }
            catch { throw error == .cancelled ? .cancelled : .access(error) }
            try Self.checkDeadline(started, budget: budget)
            pageCount += 1
            guard page.offset == offset else { throw .invalidPage(reason: "Noncontiguous page offset.") }
            guard page.bytes.byteCount <= budget.maximumPageByteCount else {
                throw .byteLimitExceeded(limit: budget.maximumPageByteCount, actual: page.bytes.byteCount)
            }
            let (end, overflow) = offset.addingReportingOverflow(page.bytes.byteCount)
            guard !overflow, end <= intent.expectedReference.byteCount,
                  end <= budget.maximumTotalByteCount, end <= UInt64(Int.max) else {
                throw .byteLimitExceeded(limit: min(intent.expectedReference.byteCount, budget.maximumTotalByteCount), actual: overflow ? UInt64.max : end)
            }
            guard page.cumulativeByteCount == end,
                  page.cumulativeWork.pageCount == pageCount,
                  page.cumulativeWork.workUnitCount >= previousWork.workUnitCount,
                  page.cumulativeWork.workUnitCount >= pageCount,
                  page.cumulativeWork.elapsedNanoseconds >= previousWork.elapsedNanoseconds else {
                throw .invalidPage(reason: "Cumulative byte or work accounting is inconsistent.")
            }
            let (captureWork, workOverflow) = pageCount.addingReportingOverflow(1)
            let (totalWork, totalOverflow) = page.cumulativeWork.workUnitCount.addingReportingOverflow(captureWork)
            guard !workOverflow, !totalOverflow, totalWork <= budget.maximumWorkUnitCount else {
                throw .workLimitExceeded(limit: budget.maximumWorkUnitCount)
            }
            guard page.cumulativeWork.elapsedNanoseconds <= budget.maximumDurationNanoseconds else { throw .deadlineExceeded }
            previousWork = page.cumulativeWork
            if case .more = page.completion {
                guard page.bytes.byteCount > 0, end < intent.expectedReference.byteCount else {
                    throw .invalidPage(reason: "A nonterminal page must make bounded forward progress.")
                }
            }
            // Foundation's byte owner lends a pointer only for this scope. Copy
            // once into the bounded capture; no borrowed pointer is retained.
            do {
                try page.bytes.withUnsafeBytes { buffer in
                    guard UInt64(buffer.count) == page.bytes.byteCount else {
                        throw PDKSourceCaptureError.invalidPage(reason: "Owned byte count disagrees with the borrowed buffer.")
                    }
                    bytes.append(contentsOf: buffer)
                }
            } catch let error as PDKSourceCaptureError { throw error }
            catch { throw .invalidPage(reason: String(describing: error)) }

            switch page.completion {
            case .more:
                break
            case .complete:
                guard let receipt = page.finalReceipt,
                      receipt.observedArtifactID == intent.expectedReference.id,
                      receipt.totalByteCount == end,
                      receipt.cumulativeWork == page.cumulativeWork else { throw .receiptMismatch }
                guard end == intent.expectedReference.byteCount else {
                    throw .byteCountMismatch(expected: intent.expectedReference.byteCount, actual: end)
                }
                try Self.checkDeadline(started, budget: budget)
                let capture = try CapturedPDKSource(reference: intent.expectedReference, bytes: bytes, digester: digester)
                try Self.checkDeadline(started, budget: budget)
                return capture
            }
        }
    }

    internal static func checkDeadline(
        _ started: ContinuousClock.Instant,
        budget: ArtifactAccessBudget
    ) throws(PDKSourceCaptureError) {
        guard !Task.isCancelled else { throw .cancelled }
        let elapsed = (ContinuousClock.now - started).components
        let seconds = UInt64(max(elapsed.seconds, 0))
        let (whole, overflow) = seconds.multipliedReportingOverflow(by: 1_000_000_000)
        let fraction = UInt64(max(elapsed.attoseconds, 0)) / 1_000_000_000
        let (nanoseconds, sumOverflow) = whole.addingReportingOverflow(fraction)
        guard !overflow, !sumOverflow, nanoseconds <= budget.maximumDurationNanoseconds else {
            throw .deadlineExceeded
        }
    }
}
