import CircuiteFoundationFileSystem
import PDKCore
import Synchronization

/// One acquisition's bridge. Short memory access retains an exact injected error
/// when Foundation's smaller generic vocabulary cannot represent its original case.
final class PDKSourceResourceControl: ArtifactSourceControl {
    let resources: any PDKAdmissionResourceAccounting
    private let failure = Mutex<PDKAdmissionResourceError?>(nil)

    init(resources: any PDKAdmissionResourceAccounting) { self.resources = resources }
    func check() throws(ArtifactSourceControlError) {
        do { try resources.check() } catch { throw record(error) }
        if Task.isCancelled { throw record(.cancelled) }
    }
    func charge(_ work: ArtifactSourceWork) throws(ArtifactSourceControlError) {
        try check()
        try charge(.readBytes, work.readBytes)
        try charge(.hashedBytes, work.hashedBytes)
        try charge(.pages, work.pages)
        try charge(.parserWork, work.workUnits)
        try charge(.scannedEntries, work.visitedEntries)
    }
    private func charge(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64)
        throws(ArtifactSourceControlError) {
        guard amount > 0 else { return }
        do { try resources.charge(PDKAdmissionCost(dimension: dimension, amount: amount)) }
        catch { throw record(error) }
    }
    func retain(_ extent: ArtifactSourceExtent) throws(ArtifactSourceControlError) -> any ArtifactSourceRetention {
        try check()
        let dimension: PDKAdmissionResourceDimension
        let amount: UInt64
        switch extent {
        case .ownedBytes(let value): dimension = .liveOwnedBytes; amount = value
        case .temporaryBytes(let value): dimension = .temporaryBytes; amount = value
        case .openResources(let value): dimension = .openResources; amount = value
        }
        do { return PDKSourceRetention(reservation: try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: amount))) }
        catch { throw record(error) }
    }
    func sourceError(_ error: ArtifactSourceDiscoveryError) -> PDKSourceCaptureError {
        switch error {
        case .control(let generic):
            return .resource(failure.withLock { $0 } ?? Self.resourceError(generic))
        case .cancelled: return .resource(.cancelled)
        case .deadlineExceeded: return .resource(.deadlineExceeded)
        case .access(let error): return error == .cancelled ? .resource(.cancelled) : .access(error)
        case .digest(let error): return .digest(error)
        case .digestAbortFailed(let primary, let abort):
            return .cleanup(primary: sourceError(primary), cleanup: .digest(abort))
        case .cleanupFailed(let primary, let reason):
            let cleanup = PDKSourceCaptureError.discovery(.cleanupFailed(primary: nil, closeReason: reason))
            if let primary { return .cleanup(primary: sourceError(primary), cleanup: cleanup) }
            return cleanup
        default: return .discovery(error)
        }
    }
    private func record(_ error: PDKAdmissionResourceError) -> ArtifactSourceControlError {
        failure.withLock { if $0 == nil { $0 = error } }
        switch error {
        case .exhausted(let dimension, let limit, let attempted):
            guard let resource = Self.sourceResource(dimension) else { return .unsupportedCapability(reason: "Resource dimension cannot cross the discovery boundary") }
            return .quotaExceeded(resource: resource, limit: limit, attempted: attempted)
        case .arithmeticOverflow(let dimension):
            guard let resource = Self.sourceResource(dimension) else { return .unsupportedCapability(reason: "Resource dimension cannot cross the discovery boundary") }
            return .arithmeticOverflow(resource: resource)
        case .cancelled: return .cancelled
        case .deadlineExceeded: return .deadlineExceeded
        case .closed: return .closed
        case .unsupportedBudgetCapability(let reason): return .unsupportedCapability(reason: reason)
        case .invalidCost: return .unsupportedCapability(reason: "Invalid PDK accounting cost")
        case .unsupportedAccountingVersion: return .unsupportedCapability(reason: "Unsupported PDK accounting version")
        }
    }
    private static func sourceResource(_ dimension: PDKAdmissionResourceDimension) -> ArtifactSourceResource? {
        switch dimension {
        case .readBytes: .readBytes
        case .hashedBytes: .hashedBytes
        case .pages: .pages
        case .parserWork: .workUnits
        case .scannedEntries: .visitedEntries
        case .liveOwnedBytes: .ownedBytes
        case .temporaryBytes: .temporaryBytes
        case .openResources: .openResources
        default: nil
        }
    }
    private static func dimension(_ resource: ArtifactSourceResource) -> PDKAdmissionResourceDimension {
        switch resource {
        case .readBytes: .readBytes
        case .hashedBytes: .hashedBytes
        case .pages: .pages
        case .workUnits: .parserWork
        case .visitedEntries: .scannedEntries
        case .ownedBytes: .liveOwnedBytes
        case .temporaryBytes: .temporaryBytes
        case .openResources: .openResources
        }
    }
    private static func resourceError(_ error: ArtifactSourceControlError) -> PDKAdmissionResourceError {
        switch error {
        case .quotaExceeded(let resource, let limit, let attempted): .exhausted(dimension: dimension(resource), limit: limit, attempted: attempted)
        case .arithmeticOverflow(let resource): .arithmeticOverflow(dimension(resource))
        case .cancelled: .cancelled
        case .deadlineExceeded: .deadlineExceeded
        case .closed: .closed
        case .unsupportedCapability(let reason): .unsupportedBudgetCapability(reason)
        }
    }
}
