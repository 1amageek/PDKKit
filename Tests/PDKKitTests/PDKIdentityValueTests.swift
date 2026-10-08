import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import Testing

@Suite("PDK identity values", .timeLimit(.minutes(1)))
struct PDKIdentityValueTests {
    private func binding(role: ArtifactRole = .input) throws -> TestArtifactBinding {
        try makeArtifactBinding(path: "/tmp/pdk.json", kind: .technology, format: .json,
                                sha256: String(repeating: "a", count: 64), byteCount: 16, role: role)
    }

    @Test("round trips preserve producer roles and qualified reference descriptors", arguments: [ArtifactRole.input, .output])
    func preservesIdentity(role: ArtifactRole) throws {
        let original = try binding(role: role)
        let content = try ArtifactReference(digest: original.reference.digest, byteCount: 16,
            descriptor: ArtifactDescriptor(role: role, kind: ArtifactKind(rawValue: "pdk.technology"), format: .json))
        let value = try PDKReference(manifest: content, manifestLocator: original.locator, processID: "fixture", version: "1")
        let decoded = try JSONDecoder().decode(PDKReference.self, from: JSONEncoder().encode(value))
        #expect(decoded.manifest == content)
        #expect(decoded.digest == content.digest.hexadecimalValue)
        #expect(decoded == value)
        let asset = try PDKResolvedAsset(assetID: "manifest", reference: content, locator: original.locator)
        #expect(try JSONDecoder().decode(PDKResolvedAsset.self, from: JSONEncoder().encode(asset)) == asset)
    }

    @Test("invalid metadata and mismatched availability are rejected")
    func rejectsInvalidClaims() throws {
        let original = try binding()
        #expect(throws: PDKReferenceError.emptyProcessID) {
            try PDKReference(manifest: original.reference, manifestLocator: original.locator, processID: " ", version: "1")
        }
        let output = try binding(role: .output)
        #expect(throws: PDKResolvedAssetError.locatorDescriptorMismatch) {
            try PDKResolvedAsset(assetID: "manifest", reference: original.reference, locator: output.locator)
        }
        #expect(throws: PDKReferenceError.locatorDescriptorMismatch) {
            try PDKReference(manifest: original.reference, manifestLocator: output.locator, processID: "fixture", version: "1")
        }
    }

    @Test("obsolete resolved-asset storage is rejected", arguments: ["path", "computedSHA256", "computedByteCount"])
    func rejectsObsoleteAssetFields(field: String) throws {
        let original = try binding()
        let asset = try PDKResolvedAsset(assetID: "manifest", reference: original.reference, locator: original.locator)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(asset)) as? [String: Any])
        object[field] = field == "computedByteCount" ? 16 : "obsolete"
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PDKResolvedAsset.self, from: JSONSerialization.data(withJSONObject: object))
        }
        object.removeValue(forKey: field)
        object["schemaVersion"] = 1
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PDKResolvedAsset.self, from: JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test("reference decoding rejects obsolete duplicate digest storage")
    func duplicateDigestIsRejected() throws {
        let binding = try makeArtifactBinding(
            artifactID: "manifest", path: "/tmp/pdk.json", kind: .technology,
            format: .json, sha256: String(repeating: "a", count: 64), byteCount: 16
        )
        let referenceData = Data("""
        {"schemaVersion":2,"manifest":\(String(decoding: try JSONEncoder().encode(binding.reference), as: UTF8.self)),
        "manifestLocator":\(String(decoding: try JSONEncoder().encode(binding.locator), as: UTF8.self)),
        "processID":"fixture","version":"1","digest":"\(String(repeating: "a", count: 64))"}
        """.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PDKReference.self, from: referenceData)
        }
    }
}
