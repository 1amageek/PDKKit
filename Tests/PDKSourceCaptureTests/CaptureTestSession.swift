import CircuiteFoundation
import Foundation

actor CaptureTestSession: ArtifactReadSession {
    nonisolated let identity: ArtifactAccessSessionIdentity
    nonisolated let expectedReference: ArtifactReference
    nonisolated let termination: CaptureTestTermination
    private let pages: [ArtifactReadPage]
    private let readFailure: ArtifactAccessError?
    private let cancelOnRead: Bool
    private(set) var readCount = 0
    private(set) var closeCount = 0

    init(reference: ArtifactReference, pages: [ArtifactReadPage], readFailure: ArtifactAccessError? = nil, closeFailure: Bool = false, cancelOnRead: Bool = false, terminalClose: Bool = true) throws {
        identity = try ArtifactAccessSessionIdentity(rawValue: UUID().uuidString)
        expectedReference = reference
        termination = CaptureTestTermination(identity: identity, failure: closeFailure, terminal: terminalClose)
        self.pages = pages
        self.readFailure = readFailure
        self.cancelOnRead = cancelOnRead
    }

    func readPage(_ request: ArtifactReadPageRequest) async throws(ArtifactAccessError) -> ArtifactReadPage {
        if let readFailure { throw readFailure }
        guard readCount < pages.count else { throw .truncatedResource }
        let page = pages[readCount]
        readCount += 1
        if cancelOnRead { withUnsafeCurrentTask { $0?.cancel() } }
        return page
    }

    func close() async -> any ArtifactAccessTermination {
        closeCount += 1
        return termination
    }
}
