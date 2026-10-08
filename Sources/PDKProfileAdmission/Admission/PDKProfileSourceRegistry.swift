import CircuiteFoundation
import Foundation
import PDKCore
import PDKSourceCapture

actor PDKProfileSourceRegistry {
    private struct Record: Sendable {
        let reference: ArtifactReference
        var result: Result<CapturedPDKSource, PDKProfileAdmissionError>?
    }
    private struct Waiter: Sendable {
        let index: Int
        let continuation: CheckedContinuation<Result<CapturedPDKSource, PDKProfileAdmissionError>, Never>
        var resumed: Bool
    }
    private let capture: any PDKBoundedLocalSourceCapturing
    private let work: PDKAdmissionWork
    private var records = PDKAdmissionCollection<Record>()
    private var waiters = PDKAdmissionCollection<Waiter>()
    init(capture: any PDKBoundedLocalSourceCapturing, resources: any PDKAdmissionResourceAccounting) {
        self.capture = capture; work = PDKAdmissionWork(resources: resources)
    }
    internal func waitingCount() -> Int {
        var count = 0
        for waiter in waiters { if !waiter.resumed { count += 1 } }
        return count
    }
    func acquire(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                 relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget)
        async throws(PDKProfileAdmissionError) -> CapturedPDKSource {
        try work.check()
        for index in records.indices {
            try work.step()
            let known = records[index].reference
            guard known.byteCount == reference.byteCount, known.digest.algorithm == reference.digest.algorithm else { continue }
            guard try work.equal(known.digest.hexadecimalValue, reference.digest.hexadecimalValue) else { continue }
            let result: Result<CapturedPDKSource, PDKProfileAdmissionError>
            if let completed = records[index].result { result = completed }
            else {
                result = await withCheckedContinuation { continuation in
                    let slot = waiters.count
                    do throws(PDKProfileAdmissionError) { try waiters.append(Waiter(index: index, continuation: continuation, resumed: false), work: work) }
                    catch {
                        if waiters.count > slot {
                            waiters.complete(at: slot, with: Waiter(index: index, continuation: continuation, resumed: true))
                        }
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
            switch result {
            case .failure(let error): throw error
            case .success(let source):
                do { return try source.rebinding(reference: reference, resources: work.resources) }
                catch { throw .source(error) }
            }
        }
        try work.charge(.uniqueSources)
        let index = records.count
        do throws(PDKProfileAdmissionError) { try records.append(Record(reference: reference, result: nil), work: work) }
        catch {
            if records.count > index { records.complete(at: index, with: Record(reference: reference, result: .failure(error))) }
            throw error
        }
        // The original structured caller owns the acquisition across this suspension.
        let result: Result<CapturedPDKSource, PDKProfileAdmissionError>
        do throws(PDKProfileAdmissionError) {
            let source: CapturedPDKSource
            do { source = try await capture.capture(reference: reference, rootURL: rootURL,
                rootID: rootID, relativePath: relativePath, budget: budget, resources: work.resources) }
            catch { throw .source(error) }
            guard try work.equal(source.reference, reference) else { throw .providerIdentity }
            // Rebinding to itself also proves the injected capture has a bounded owner.
            do { result = .success(try source.rebinding(reference: reference, resources: work.resources)) }
            catch { throw .source(error) }
        } catch { result = .failure(error) }
        records.complete(at: index, with: Record(reference: reference, result: result))
        for slot in waiters.indices where waiters[slot].index == index && !waiters[slot].resumed {
            var waiter = waiters[slot]; waiter.resumed = true
            waiters.complete(at: slot, with: waiter)
            waiter.continuation.resume(returning: result)
        }
        switch result { case .success(let source): return source; case .failure(let error): throw error }
    }
}
