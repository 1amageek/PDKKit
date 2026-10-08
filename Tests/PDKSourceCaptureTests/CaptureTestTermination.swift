import CircuiteFoundation
import Foundation

actor CaptureTestTermination: ArtifactAccessTermination {
    nonisolated let sessionIdentity: ArtifactAccessSessionIdentity
    private let failure: Bool
    private let terminal: Bool
    private(set) var waitCount = 0

    init(identity: ArtifactAccessSessionIdentity, failure: Bool, terminal: Bool) {
        sessionIdentity = identity
        self.failure = failure
        self.terminal = terminal
    }

    func wait() async throws(ArtifactAccessTerminationError) -> ArtifactAccessTerminationReceipt {
        waitCount += 1
        if failure { throw .cleanupFailed(reason: "injected close") }
        return ArtifactAccessTerminationReceipt(sessionIdentity: sessionIdentity, didReachTerminalPage: terminal)
    }
}
