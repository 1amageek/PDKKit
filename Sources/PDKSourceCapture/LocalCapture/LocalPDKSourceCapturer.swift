import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
import Foundation

public struct LocalPDKSourceCapturer: PDKLocalSourceCapturing {
    private let digester: any ContentDigesting

    public init(digester: any ContentDigesting = SHA256ContentDigester()) {
        self.digester = digester
    }

    public func capture(
        reference: ArtifactReference,
        at locator: ArtifactLocator,
        relativeTo selectedRoot: URL? = nil,
        budget: ArtifactAccessBudget
    ) async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        let started = ContinuousClock.now
        try StandardPDKSourceCapturer.checkDeadline(started, budget: budget)
        // Locator metadata describes availability. The expected reference owns
        // the canonical descriptor, which may normalize the locator's kind.
        let rootURL: URL
        let segments: [String]
        switch locator.location.storage {
        case .workspaceRelative:
            guard let selectedRoot else { throw .invalidLocation(reason: "A relative source requires an explicit root.") }
            rootURL = selectedRoot
            segments = locator.location.value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        case .absoluteFileURL:
            guard let fileURL = URL(string: locator.location.value), fileURL.isFileURL else {
                throw .invalidLocation(reason: "Source location is not a file URL.")
            }
            // Retain all lexical path components below the explicit root.
            // Foundation's root-relative open rejects symlinks; URL resolution
            // must not resolve them before the secure backend observes them.
            let fileComponents = fileURL.standardizedFileURL.pathComponents
            if let selectedRoot {
                rootURL = selectedRoot
                let rootComponents = selectedRoot.standardizedFileURL.pathComponents
                guard fileComponents.count > rootComponents.count,
                      Array(fileComponents.prefix(rootComponents.count)) == rootComponents else {
                    throw .invalidLocation(reason: "Source is outside the explicit root.")
                }
                segments = Array(fileComponents.dropFirst(rootComponents.count))
            } else {
                rootURL = fileURL.deletingLastPathComponent()
                segments = [fileURL.lastPathComponent]
            }
        }
        let intent: ArtifactAccessIntent
        let rootID: ArtifactRootID
        do {
            rootID = try ArtifactRootID(rawValue: UUID().uuidString)
            intent = try ArtifactAccessIntent(
                expectedReference: reference,
                availability: .local(artifactID: reference.id, rootID: rootID, relativePath: ArtifactRelativePath(segments: segments)),
                operation: .read,
                budget: budget
            )
        } catch { throw .invalidLocation(reason: String(describing: error)) }
        let root: ArtifactRootCapability
        do { root = try ArtifactRootCapability(rootID: rootID, directoryURL: rootURL, digester: digester) }
        catch { throw .root(error) }
        let result: Result<CapturedPDKSource, PDKSourceCaptureError>
        do { result = .success(try await StandardPDKSourceCapturer(access: root, digester: digester).capture(intent)) }
        catch { result = .failure(error) }
        do { try await root.close().wait() }
        catch {
            switch result {
            case .failure(let primary): throw .cleanup(primary: primary, cleanup: .root(error))
            case .success: throw .root(error)
            }
        }
        if Task.isCancelled {
            if case .failure(let primary) = result { throw primary }
            throw .cancelled
        }
        switch result {
        case .success(let captured):
            try StandardPDKSourceCapturer.checkDeadline(started, budget: budget)
            return captured
        case .failure(let error): throw error
        }
    }
}
