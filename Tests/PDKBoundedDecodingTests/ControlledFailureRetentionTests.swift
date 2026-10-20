import Foundation
import Testing
import PDKCore
import PDKDiscovery

@Suite(.timeLimit(.minutes(1))) struct ControlledFailureRetentionTests {
    private struct RejectedAssetPath: Decodable, Sendable {
        init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            throw PDKManifestError.invalidAssetPath(value)
        }
    }

    @Test func decodedCauseStorageSurvivesCopiedPublicFailureUntilFinalRelease() throws {
        let path = String(repeating: "invalid/asset/path/", count: 256)
        let bytes = Array(try JSONEncoder().encode(path))
        let accounting = DecodeTestAccounting()
        var first: PDKControlledDecodeFailure?
        do {
            _ = try NativePDKBoundedDocumentDecoder().decodeAudited(RejectedAssetPath.self,
                bytes: bytes.span, accounting: accounting, rejectUnknownFields: false, validate: { _ in })
            Issue.record("Invalid path was accepted")
        } catch { first = error }
        var copy = first
        first = nil
        if case .manifest(.invalidAssetPath(let original)) = copy?.cause {
            #expect(original == path)
        } else { Issue.record("Original invalid-asset-path cause was lost") }
        #expect(accounting.amount(.liveOwnedBytes) >= UInt64(path.utf8.count))
        copy = nil
        #expect(accounting.amount(.liveOwnedBytes) == 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
        // Refusal before failure-metadata admission must not start input work.
        // The trusted accountant's already-owned typed cause remains unchanged.
        for upstream in [PDKAdmissionResourceError.cancelled,
            .unsupportedBudgetCapability(String(repeating: "caller-owned-", count: 1024))] {
            let bootstrap = DecodeTestAccounting(cancelAfterChecks: 1, failure: upstream)
            do {
                _ = try NativePDKBoundedDocumentDecoder().decodeAudited(RejectedAssetPath.self,
                    bytes: bytes.span, accounting: bootstrap, rejectUnknownFields: false, validate: { _ in })
                Issue.record("Bootstrap refusal was ignored")
            } catch {
                #expect(error.cause == .resource(upstream))
            }
            #expect(bootstrap.amount(.decodedElements) == 0)
            #expect(bootstrap.amount(.liveOwnedBytes) == 0)
            #expect(bootstrap.amount(.temporaryBytes) == 0)
        }
    }
    @Test func bootstrapPreservesAccountantOwnedTypedCauseExactly() throws {
        let sentinel = "original-accountant-cause-" + String(repeating: "caller-owned/", count: 256)
        let original = PDKAdmissionResourceError.unsupportedBudgetCapability(sentinel)
        let accounting = DecodeTestAccounting(cancelAfterChecks: 1, failure: original)
        let bytes = Array(#""unused""#.utf8)
        do {
            _ = try NativePDKBoundedDocumentDecoder().decodeAudited(RejectedAssetPath.self,
                bytes: bytes.span, accounting: accounting, rejectUnknownFields: false, validate: { _ in })
            Issue.record("Upstream bootstrap refusal was ignored")
        } catch {
            #expect(error.cause == .resource(original))
        }
        #expect(accounting.amount(.decodedElements) == 0)
        #expect(accounting.amount(.liveOwnedBytes) == 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
    }

}
