import Foundation
import Testing
import PDKCore
import PDKSourceCapture
import CircuiteFoundation
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
@testable import PDKDiscovery

@Suite(.timeLimit(.minutes(1))) struct BoundedDecodingTests {
    func decode<T: Decodable & Sendable>(_ type: T.Type, _ json: String, _ accounting: DecodeTestAccounting = DecodeTestAccounting())
        throws -> PDKDecodedDocument<T> {
        let bytes = Array(json.utf8)
        return try NativePDKBoundedDocumentDecoder().decode(type, bytes: bytes.span, accounting: accounting)
    }
    func decode<T: Decodable & Sendable>(_ value: T, accounting: DecodeTestAccounting = DecodeTestAccounting())
        throws -> PDKDecodedDocument<T> where T: Encodable {
        let bytes = Array(try JSONEncoder().encode(value))
        return try NativePDKBoundedDocumentDecoder().decode(T.self, bytes: bytes.span, accounting: accounting)
    }
    @Test func publicEntryDecodesExactCaptureAfterFileRemoval() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "pdk-bounded-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record("Fixture cleanup failed: \(error)") }
        }
        let url = root.appending(path: "pdk.json")
        let manifest = PDKManifest(processID: "captured-process", version: "1")
        try JSONEncoder().encode(manifest).write(to: url)
        let locator = ArtifactLocator(location: try ArtifactLocation(fileURL: url), role: .output, kind: .technology, format: .json)
        let reference = try LocalArtifactReferencer().reference(locator, relativeTo: root)
        let captured = try await LocalPDKSourceCapturer().capture(reference: reference, at: locator, relativeTo: root,
            budget: PDKSourceCapturePolicy.defaultBudget)
        try FileManager.default.removeItem(at: url)
        let decoder: any PDKBoundedDocumentDecoding = NativePDKBoundedDocumentDecoder()
        let loaded = try decoder.decodeManifest(captured, accounting: DecodeTestAccounting())
        #expect(loaded.value == manifest)
        #expect(loaded.sourceReference == reference)
        #expect(loaded.sourceReference?.descriptor.role == .output)
        let profileValues = try BoundedDecodeFixture.values()
        try JSONEncoder().encode(profileValues.1).write(to: url)
        let definitionReference = try LocalArtifactReferencer().reference(locator, relativeTo: root)
        let definitionSource = try await LocalPDKSourceCapturer().capture(reference: definitionReference,
            at: locator, relativeTo: root, budget: PDKSourceCapturePolicy.defaultBudget)
        try FileManager.default.removeItem(at: url)
        let decodedDefinition = try decoder.decodeDefinition(definitionSource, accounting: DecodeTestAccounting())
        #expect(decodedDefinition.value == profileValues.1)
        #expect(decodedDefinition.sourceReference == definitionReference)
        #expect(decodedDefinition.sourceReference?.descriptor.role == .output)
        try JSONEncoder().encode(profileValues.2).write(to: url)
        let claimReference = try LocalArtifactReferencer().reference(locator, relativeTo: root)
        let claimSource = try await LocalPDKSourceCapturer().capture(reference: claimReference,
            at: locator, relativeTo: root, budget: PDKSourceCapturePolicy.defaultBudget)
        try FileManager.default.removeItem(at: url)
        let decodedClaim = try decoder.decodeClaim(claimSource, accounting: DecodeTestAccounting())
        #expect(decodedClaim.value == profileValues.2)
        #expect(decodedClaim.sourceReference == claimReference)
        #expect(decodedClaim.sourceReference?.descriptor.role == .output)
    }
    @Test func checkedManifestDefinitionAndClaimRoundTrip() throws {
        let values = try BoundedDecodeFixture.values()
        #expect(try decode(values.0).value == values.0)
        #expect(try decode(values.1).value == values.1)
        #expect(try decode(values.2).value == values.2)
        let invalid = "{\"schemaVersion\":2}"
        #expect(throws: PDKBoundedDecodeError.manifest(.unsupportedSchemaVersion(2))) {
            try decode(PDKManifest.self, invalid)
        }
        let data = try JSONEncoder().encode(values.1)
        let missing = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"profileID\":\"demo\"", with: "\"profileID\":\"\"")
        #expect(throws: PDKBoundedDecodeError.self) { try decode(PDKProfileDefinition.self, missing) }
    }
    @Test func duplicateKeysAndMalformedSyntaxFail() throws {
        for json in ["{\"a\":1,\"a\":2}", "{\"a\":1,\"\\u0061\":2}"] {
            do { _ = try decode([String: Int].self, json); Issue.record("Duplicate key accepted") }
            catch let error as PDKBoundedDecodeError {
                guard case .duplicateKey = error else { Issue.record("Unexpected failure: \(error)"); continue }
            }
        }
        for json in ["[1,]", "{\"a\":1,}", "01", "1.", "1e", "true false", "\"\\uD800\"", "\"\\uDC00\"", "\"\\x00\""] {
            #expect(throws: PDKBoundedDecodeError.self) { try decode(Int.self, json) }
        }
        let invalid: [UInt8] = [34, 0xC0, 0xAF, 34]
        #expect(throws: PDKBoundedDecodeError.invalidUTF8(byteOffset: 1)) {
            try NativePDKBoundedDocumentDecoder().decode(String.self, bytes: invalid.span, accounting: DecodeTestAccounting())
        }
        #expect(try decode(String.self, "\"\\uD83D\\uDE00\"").value == "😀")
    }
    @Test func hostileUnusedNestingUsesAnIterativeArena() throws {
        let manifest = PDKManifest(processID: "p", version: "1")
        let encoded = String(decoding: try JSONEncoder().encode(manifest), as: UTF8.self)
        let json = String(encoded.dropLast()) + ",\"unused\":" + String(repeating: "[", count: 2048)
            + "null" + String(repeating: "]", count: 2048) + "}"
        let accounting = DecodeTestAccounting(limits: [.decodeNesting: 2049])
        #expect(try decode(PDKManifest.self, json, accounting).value == manifest)
        #expect(accounting.amount(.decodeNesting) == 0)
    }
    @Test func exactIntegerLimitsAndFiniteNumbers() throws {
        #expect(try decode(Int64.self, "-9223372036854775808").value == Int64.min)
        #expect(try decode(UInt64.self, "18446744073709551615").value == UInt64.max)
        #expect(try decode(UInt64.self, "184467440737095516150e-1").value == UInt64.max)
        #expect(try decode(Int.self, "1.20e2").value == 120)
        for json in ["9223372036854775808", "1.1", "1e999999999999999999999", "1e309"] {
            #expect(throws: PDKBoundedDecodeError.self) { try decode(Int64.self, json) }
        }
        #expect(throws: PDKBoundedDecodeError.self) { try decode(UInt64.self, "18446744073709551616") }
        #expect(throws: PDKBoundedDecodeError.self) { try decode(UInt64.self, "-1") }
    }
    @Test func cumulativeElementsScalarsAndWorkDoNotReset() throws {
        let elements = DecodeTestAccounting(limits: [.decodedElements: 4])
        _ = try decode([Int].self, "[1,2]", elements)
        #expect(throws: PDKBoundedDecodeError.self) { try decode([Int].self, "[1]", elements) }
        let scalars = DecodeTestAccounting(limits: [.scalarBytes: 5])
        _ = try decode(String.self, "\"abc\"", scalars)
        #expect(throws: PDKBoundedDecodeError.self) { try decode(String.self, "\"def\"", scalars) }
        let work = DecodeTestAccounting(limits: [.parserWork: 3])
        #expect(throws: PDKBoundedDecodeError.self) { try decode(String.self, "\"long\"", work) }
    }
    @Test func liveNestingTemporaryAndOwnedExhaustionRelease() throws {
        for dimension: PDKAdmissionResourceDimension in [.decodeNesting, .temporaryBytes, .liveOwnedBytes] {
            let accounting = DecodeTestAccounting(limits: [dimension: 1])
            #expect(throws: PDKBoundedDecodeError.self) { try decode([[String]].self, "[[\"abc\"]]", accounting) }
            #expect(accounting.amount(.decodeNesting) == 0)
            #expect(accounting.amount(.temporaryBytes) == 0)
            #expect(accounting.amount(.liveOwnedBytes) == 0)
        }
    }
    @Test func retainedValueOwnerReleasesOnlyAfterLastCopy() throws {
        let accounting = DecodeTestAccounting()
        var first: PDKDecodedDocument<[String]>? = try decode([String].self, "[\"alpha\",\"beta\"]", accounting)
        var second = first
        #expect(accounting.amount(.liveOwnedBytes) > 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
        first = nil
        #expect(second?.value == ["alpha", "beta"])
        #expect(accounting.amount(.liveOwnedBytes) > 0)
        second = nil
        #expect(accounting.amount(.liveOwnedBytes) == 0)
    }
    @Test func deadlineAtPublicationCannotReturnLateSuccess() throws {
        let observed = DecodeTestAccounting()
        _ = try decode(Bool.self, "true", observed)
        let finalCheck = observed.state.withLock { $0.checks }
        let expired = DecodeTestAccounting(cancelAfterChecks: finalCheck, failure: .deadlineExceeded)
        #expect(throws: PDKBoundedDecodeError.resource(.deadlineExceeded)) { try decode(Bool.self, "true", expired) }
        #expect(expired.amount(.temporaryBytes) == 0)
        #expect(expired.amount(.liveOwnedBytes) == 0)
    }
    @Test func cancellationIsTypedAndPublishesNothing() throws {
        let accounting = DecodeTestAccounting(cancelAfterChecks: 30)
        #expect(throws: PDKBoundedDecodeError.resource(.cancelled)) {
            try decode([String].self, "[\"" + String(repeating: "x", count: 2048) + "\"]", accounting)
        }
        #expect(accounting.amount(.temporaryBytes) == 0)
        #expect(accounting.amount(.liveOwnedBytes) == 0)
        #expect(accounting.amount(.decodeNesting) == 0)
    }
}
