import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation

public struct PDKResolvedAsset: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2
    public let assetID: String
    public let reference: ArtifactReference
    public let locator: ArtifactLocator
    public var path: String { locator.path }

    public init(assetID: String, reference: ArtifactReference, locator: ArtifactLocator) throws(PDKResolvedAssetError) {
        guard !assetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw .emptyAssetID }
        guard PDKIdentityDescriptorPolicy.matches(locator, reference: reference) else { throw .locatorDescriptorMismatch }
        self.assetID = assetID
        self.reference = reference
        self.locator = locator
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, assetID, reference, locator, path, computedSHA256, computedByteCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try container.decode(Int.self, forKey: .schemaVersion)
        guard schema == Self.currentSchemaVersion else { throw PDKResolvedAssetError.unsupportedSchemaVersion(schema) }
        for key in [CodingKeys.path, .computedSHA256, .computedByteCount] where container.contains(key) {
            throw PDKResolvedAssetError.obsoleteIdentityField(key.rawValue)
        }
        try self.init(
            assetID: container.decode(String.self, forKey: .assetID),
            reference: container.decode(ArtifactReference.self, forKey: .reference),
            locator: container.decode(ArtifactLocator.self, forKey: .locator)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(assetID, forKey: .assetID)
        try container.encode(reference, forKey: .reference)
        try container.encode(locator, forKey: .locator)
    }
}
