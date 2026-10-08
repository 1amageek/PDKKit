import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFoundation
import Foundation
import PDKCore
@testable import PDKProfileAdmission
import PDKSourceCapture
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CaptureAliasingTests {
    private struct Fixture {
        let root: URL
        let rootID: ArtifactRootID
        let path: ArtifactRelativePath
        let descriptor = ArtifactDescriptor(role: .input, kind: .report, format: .text)
        let bytes = Data([1, 2, 3, 4])
        init() throws {
            root = FileManager.default.temporaryDirectory.appending(path: "pdk-alias-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            rootID = try ArtifactRootID(rawValue: UUID().uuidString)
            path = try ArtifactRelativePath(segments: ["source"])
            try bytes.write(to: root.appending(path: "source"))
        }
        func cleanup() {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record("Alias fixture cleanup failed: \(error)") }
        }
    }

    private func resources() throws -> LocalPDKAdmissionResources {
        let limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64.max) })
        return LocalPDKAdmissionResources(budget: try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: UInt64.max))
    }

    private func capture(_ fixture: Fixture, resources: LocalPDKAdmissionResources) async throws -> CapturedPDKSource {
        try await LocalPDKBoundedSourceCapturer().discover(descriptor: fixture.descriptor,
            rootURL: fixture.root, rootID: fixture.rootID, relativePath: fixture.path,
            budget: PDKSourceCapturePolicy.defaultBudget, resources: resources)
    }

    @Test func descriptorAliasSharesExactBackingAndLastCopyLeaseWithoutNewIOOrHash() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = try resources()
        var last: CapturedPDKSource?
        do {
            let original = try await capture(fixture, resources: resources)
            let read = resources.used(.readBytes), hashed = resources.used(.hashedBytes)
            let owned = resources.used(.liveOwnedBytes)
            let reference = ArtifactReference(id: original.reference.id,
                descriptor: ArtifactDescriptor(role: .output, kind: .report, format: .json))
            try FileManager.default.removeItem(at: fixture.root.appending(path: "source"))
            let alias = try original.rebinding(reference: reference, resources: resources)
            #expect(alias.reference == reference)
            let shared = original.withBytes { lhs in
                alias.withBytes { rhs in
                    lhs.withUnsafeBufferPointer { left in
                        rhs.withUnsafeBufferPointer { right in left.baseAddress == right.baseAddress }
                    }
                }
            }
            #expect(shared)
            #expect(resources.used(.readBytes) == read)
            #expect(resources.used(.hashedBytes) == hashed)
            #expect(resources.used(.liveOwnedBytes) == owned)
            last = alias
        }
        #expect(resources.used(.liveOwnedBytes) == 4)
        resources.close()
        #expect(last?.withBytes { $0[0] } == 1)
        last = nil
        #expect(resources.used(.liveOwnedBytes) == 0)
    }

    @Test func changedContentAndClosedInvocationRefuseAliases() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = try resources()
        let source = try await capture(fixture, resources: resources)
        let count = try ArtifactReference(digest: source.reference.digest, byteCount: source.reference.byteCount + 1,
            descriptor: source.reference.descriptor)
        #expect(throws: PDKSourceCaptureError.byteCountMismatch(expected: 5, actual: 4)) {
            try source.rebinding(reference: count, resources: resources)
        }
        let digest = try ContentDigest(algorithm: .sha256, hexadecimalValue: String(repeating: "0", count: 64))
        let changed = try ArtifactReference(digest: digest, byteCount: 4, descriptor: source.reference.descriptor)
        #expect(throws: PDKSourceCaptureError.digestMismatch(expected: digest, actual: source.reference.digest)) {
            try source.rebinding(reference: changed, resources: resources)
        }
        resources.close()
        #expect(throws: PDKSourceCaptureError.resource(.closed)) {
            try source.rebinding(reference: source.reference, resources: resources)
        }
        withExtendedLifetime(source) {}
    }

    @Test func legacyUnaccountedCaptureCannotEnterTheProfileAliasPath() async throws {
        let fixture = try Fixture(); defer { fixture.cleanup() }
        let resources = try resources()
        let observed = try await capture(fixture, resources: resources)
        let locator = try ArtifactLocator(location: ArtifactLocation(workspaceRelativePath: "source"),
            role: fixture.descriptor.role, kind: fixture.descriptor.kind, format: fixture.descriptor.format)
        let legacy = try await LocalPDKSourceCapturer().capture(reference: observed.reference,
            at: locator, relativeTo: fixture.root,
            budget: PDKSourceCapturePolicy.defaultBudget)
        #expect(throws: PDKSourceCaptureError.resource(.unsupportedBudgetCapability("Profile aliasing requires invocation-accounted source storage"))) {
            try legacy.rebinding(reference: legacy.reference, resources: resources)
        }
    }
}
