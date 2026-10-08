import CircuiteFoundation
import CircuiteFoundationFoundation
import Darwin
import Foundation
import PDKSourceCapture
import Testing

@Suite(.timeLimit(.minutes(1)))
struct LocalPDKSourceCaptureTests {
    @Test
    func realCaptureRetainsOriginalBytesAfterMutationAndRemoval() async throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        let file = root.appendingPathComponent("input.json")
        let bytes = Array("original".utf8)
        try Data(bytes).write(to: file)
        let reference = try captureReference(bytes)
        let locator = try relativeLocator("input.json")
        let capture = try await LocalPDKSourceCapturer().capture(reference: reference, at: locator, relativeTo: root, budget: PDKSourceCapturePolicy.defaultBudget)
        try Data("replaced".utf8).write(to: file)
        try FileManager.default.removeItem(at: file)
        #expect(try capture.data(maximumByteCount: 64) == Data(bytes))
        #expect(capture.reference == reference)
    }

    @Test
    func absoluteAvailabilityWithoutAnExplicitRootWorks() async throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        let file = root.appendingPathComponent("input.json")
        try Data([97]).write(to: file)
        let reference = try captureReference([97])
        let locator = try ArtifactLocator(location: ArtifactLocation(fileURL: file), role: .input, kind: .report, format: .json)
        let capture = try await LocalPDKSourceCapturer().capture(reference: reference, at: locator, budget: PDKSourceCapturePolicy.defaultBudget)
        #expect(try capture.data(maximumByteCount: 1) == Data([97]))
    }

    @Test
    func normalizedReferenceDescriptorIsIndependentOfLocatorMetadata() async throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        let file = root.appendingPathComponent("input.json")
        try Data([97]).write(to: file)
        let original = try captureReference([97])
        let expected = ArtifactReference(id: original.id, descriptor: ArtifactDescriptor(role: .input, kind: try ArtifactKind(rawValue: "pdk.technology"), format: .json))
        let locator = try ArtifactLocator(location: ArtifactLocation(workspaceRelativePath: "input.json"), role: .input, kind: .technology, format: .json)
        let captured = try await LocalPDKSourceCapturer().capture(reference: expected, at: locator, relativeTo: root, budget: PDKSourceCapturePolicy.defaultBudget)
        #expect(captured.reference == expected)
        #expect(captured.reference.descriptor != locator.descriptor)
    }

    @Test
    func sameLengthTamperingIsRejected() async throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        let file = root.appendingPathComponent("input.json")
        let reference = try captureReference(Array("original".utf8))
        try Data("replaced".utf8).write(to: file)
        await #expect(throws: PDKSourceCaptureError.self) {
            _ = try await LocalPDKSourceCapturer().capture(reference: reference, at: relativeLocator("input.json"), relativeTo: root, budget: PDKSourceCapturePolicy.defaultBudget)
        }
    }

    @Test(arguments: ["leaf", "ancestor"])
    func rootRelativeSymlinksAreRejected(_ variant: String) async throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        let real = root.appendingPathComponent("real", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let file = real.appendingPathComponent("input.json")
        try Data([97]).write(to: file)
        let path: String
        if variant == "leaf" {
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("input.json"), withDestinationURL: file)
            path = "input.json"
        } else {
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked"), withDestinationURL: real)
            path = "linked/input.json"
        }
        do {
            _ = try await LocalPDKSourceCapturer().capture(reference: captureReference([97]), at: relativeLocator(path), relativeTo: root, budget: PDKSourceCapturePolicy.defaultBudget)
            Issue.record("Symlink source was admitted.")
        } catch let error as PDKSourceCaptureError {
            if variant == "leaf" {
                #expect(error == .access(.symlinkTraversal(componentIndex: 0)))
            } else {
                // The fixed Darwin backend combines O_NOFOLLOW and O_DIRECTORY
                // for ancestor components; a symlink there reports ENOTDIR.
                #expect(error == .access(.openFailed(componentIndex: 0, reason: String(cString: strerror(ENOTDIR)))))
            }
        } catch {
            Issue.record("Unexpected setup error: \(error)")
        }
    }

    @Test
    func absoluteSourceOutsideExplicitRootIsRejected() async throws {
        let root = try temporaryRoot()
        let outside = try temporaryRoot()
        defer { removeRoot(root); removeRoot(outside) }
        let file = outside.appendingPathComponent("input.json")
        try Data([97]).write(to: file)
        let locator = try ArtifactLocator(location: ArtifactLocation(fileURL: file), role: .input, kind: .report, format: .json)
        await #expect(throws: PDKSourceCaptureError.self) {
            _ = try await LocalPDKSourceCapturer().capture(reference: captureReference([97]), at: locator, relativeTo: root, budget: PDKSourceCapturePolicy.defaultBudget)
        }
    }

    @Test
    func missingFileAndByteBudgetFailClosed() async throws {
        let root = try temporaryRoot()
        defer { removeRoot(root) }
        let reference = try captureReference([97, 98, 99, 100])
        await #expect(throws: PDKSourceCaptureError.self) {
            _ = try await LocalPDKSourceCapturer().capture(reference: reference, at: relativeLocator("missing.json"), relativeTo: root, budget: PDKSourceCapturePolicy.defaultBudget)
        }
        try Data([97, 98, 99, 100]).write(to: root.appendingPathComponent("input.json"))
        await #expect(throws: PDKSourceCaptureError.byteLimitExceeded(limit: 2, actual: 4)) {
            _ = try await LocalPDKSourceCapturer().capture(reference: reference, at: relativeLocator("input.json"), relativeTo: root, budget: captureBudget(total: 2))
        }
    }

    private func relativeLocator(_ path: String) throws -> ArtifactLocator {
        try ArtifactLocator(location: ArtifactLocation(workspaceRelativePath: path), role: .input, kind: .report, format: .json)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func removeRoot(_ root: URL) {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record("Temporary root cleanup failed: \(error)") }
    }
}
