import CircuiteFoundation
import Foundation

actor CaptureTestAccess: ArtifactAccessing {
    let session: CaptureTestSession
    private(set) var openCount = 0

    init(session: CaptureTestSession) { self.session = session }

    func open(_ intent: ArtifactAccessIntent) async throws(ArtifactAccessError) -> any ArtifactReadSession {
        openCount += 1
        return session
    }
}
