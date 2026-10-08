import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFileSystem
import Foundation
import PDKCore

/// Profile input through the public controlled Foundation discovery path.
public struct LocalPDKBoundedSourceCapturer: PDKBoundedLocalSourceCapturing, PDKLocalSourceDiscovering, PDKLocalSourceEnumerating {
    private let digester: any ContentDigesting
    private let roots: any PDKSourceRootOpening
    public init(digester: any ContentDigesting = SHA256ContentDigester(),
                roots: any PDKSourceRootOpening = FoundationPDKSourceRootOpener()) {
        self.digester = digester; self.roots = roots
    }
    public func capture(reference: ArtifactReference, rootURL: URL, rootID: ArtifactRootID,
                        relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                        resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        let work = PDKSourceConstructionWork(resources: resources)
        try work.check()
        guard reference.byteCount <= budget.maximumTotalByteCount, reference.byteCount <= UInt64(Int.max) else {
            throw .byteLimitExceeded(limit: min(budget.maximumTotalByteCount, UInt64(Int.max)), actual: reference.byteCount)
        }
        return try await observe(descriptor: reference.descriptor, expected: reference,
            rootURL: rootURL, rootID: rootID, relativePath: relativePath, budget: budget, resources: resources)
    }
    public func discover(descriptor: ArtifactDescriptor, rootURL: URL, rootID: ArtifactRootID,
                         relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                         resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        try await observe(descriptor: descriptor, expected: nil, rootURL: rootURL, rootID: rootID,
            relativePath: relativePath, budget: budget, resources: resources)
    }
    private func observe(descriptor: ArtifactDescriptor, expected: ArtifactReference?,
                         rootURL: URL, rootID: ArtifactRootID, relativePath: ArtifactRelativePath,
                         budget: ArtifactAccessBudget, resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        try await withRoot(rootURL: rootURL, rootID: rootID,
            maximumDurationNanoseconds: budget.maximumDurationNanoseconds, resources: resources) {
            (root, control, work) async throws(PDKSourceCaptureError) in
            let observed: ArtifactDiscoveredSource
            do throws(ArtifactSourceDiscoveryError) {
                observed = try await root.discover(.init(rootID: rootID, relativePath: relativePath,
                    descriptor: descriptor, budget: budget), control: control)
            } catch { throw control.sourceError(error) }
            try work.check()
            if let expected {
                guard try work.equal(observed.reference, expected) else {
                    if observed.reference.byteCount != expected.byteCount {
                        throw .byteCountMismatch(expected: expected.byteCount, actual: observed.reference.byteCount)
                    }
                    if observed.reference.digest != expected.digest {
                        throw .digestMismatch(expected: expected.digest, actual: observed.reference.digest)
                    }
                    throw .receiptMismatch
                }
            }
            return try materialize(observed, work: work)
        }
    }
    public func enumerate(intent: ArtifactDirectoryInventoryIntent, rootURL: URL,
                          resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSourceCaptureError) -> ArtifactDirectoryInventory {
        try await withRoot(rootURL: rootURL, rootID: intent.rootID,
            maximumDurationNanoseconds: intent.maximumDurationNanoseconds, resources: resources) {
            (root, control, _) async throws(PDKSourceCaptureError) in
            do throws(ArtifactSourceDiscoveryError) { return try await root.enumerate(intent, control: control) }
            catch { throw control.sourceError(error) }
        }
    }
    private func withRoot<Value: Sendable>(rootURL: URL, rootID: ArtifactRootID,
        maximumDurationNanoseconds: UInt64, resources: any PDKAdmissionResourceAccounting,
        operation: (any PDKSourceDiscoveryRoot, PDKSourceResourceControl, PDKSourceConstructionWork)
            async throws(PDKSourceCaptureError) -> Value)
        async throws(PDKSourceCaptureError) -> Value {
        let started = ContinuousClock.now
        let work = PDKSourceConstructionWork(resources: resources)
        try work.checkDeadline(started, maximumNanoseconds: maximumDurationNanoseconds)
        let acquisition = try work.reserve(.concurrentAcquisitions, 1)
        let rootDescriptor = try work.reserve(.openResources, 1)
        defer { withExtendedLifetime(acquisition) {}; withExtendedLifetime(rootDescriptor) {} }
        let root: any PDKSourceDiscoveryRoot
        do { root = try roots.open(rootID: rootID, directoryURL: rootURL, digester: digester) }
        catch { throw .root(error) }
        let control = PDKSourceResourceControl(resources: resources)
        let result: Result<Value, PDKSourceCaptureError>
        do throws(PDKSourceCaptureError) {
            try work.checkDeadline(started, maximumNanoseconds: maximumDurationNanoseconds)
            result = .success(try await operation(root, control, work))
        } catch { result = .failure(error) }
        do { try await root.shutdown() }
        catch {
            switch result {
            case .failure(let primary): throw .cleanup(primary: primary, cleanup: .root(error))
            case .success: throw .root(error)
            }
        }
        switch result {
        case .failure(let error): throw error
        case .success(let value):
            try work.checkDeadline(started, maximumNanoseconds: maximumDurationNanoseconds)
            return value
        }
    }
    private func materialize(_ source: ArtifactDiscoveredSource, work: PDKSourceConstructionWork)
        throws(PDKSourceCaptureError) -> CapturedPDKSource {
        guard let capacity = Int(exactly: source.byteCount) else { throw .resource(.arithmeticOverflow(.liveOwnedBytes)) }
        let reservation = try work.reserve(.liveOwnedBytes, source.byteCount)
        var bytes: [UInt8] = []; bytes.reserveCapacity(capacity)
        var primary: PDKSourceCaptureError?
        do {
            // Foundation's rethrows borrow erases the callback's typed error.
            try source.withUnsafeBytePages { page in
                do throws(PDKSourceCaptureError) {
                    try work.check()
                    let (end, overflow) = bytes.count.addingReportingOverflow(page.count)
                    guard !overflow, end <= capacity else { throw .invalidPage(reason: "Observed pages exceed their declared extent") }
                    try work.charge(.parserWork, UInt64(page.count))
                    bytes.append(contentsOf: page)
                    try work.check()
                } catch { primary = error; throw error }
            }
        } catch {
            if let primary { throw primary }
            throw .invalidPage(reason: "Borrowed source page traversal failed")
        }
        return try CapturedPDKSource(reference: source.reference, bytes: bytes, digester: digester,
            resources: work.resources, reservation: reservation)
    }
}
