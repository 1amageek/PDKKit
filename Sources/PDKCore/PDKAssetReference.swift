import CircuiteFoundation
import Foundation
import CircuiteFoundation

public struct PDKAssetReference: Sendable, Hashable, Codable {
    public var assetID: String
    public var role: PDKAssetRole
    public var path: String
    public var kind: ArtifactKind
    public var format: ArtifactFormat
    public var required: Bool
    public var sha256: String?
    public var byteCount: Int64?
    public var cornerIDs: [String]
    public var metadata: [String: String]

    public init(
        assetID: String,
        role: PDKAssetRole,
        path: String,
        kind: ArtifactKind,
        format: ArtifactFormat,
        required: Bool = true,
        sha256: String? = nil,
        byteCount: Int64? = nil,
        cornerIDs: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.assetID = assetID
        self.role = role
        self.path = path
        self.kind = kind
        self.format = format
        self.required = required
        self.sha256 = sha256
        self.byteCount = byteCount
        self.cornerIDs = cornerIDs
        self.metadata = metadata
    }

    /// Returns the Foundation intent for this asset before it is materialized.
    public func artifactLocator() throws -> ArtifactLocator {
        ArtifactLocator(
            location: try ArtifactLocation(workspaceRelativePath: path),
            role: .input,
            kind: try ArtifactKind(rawValue: "pdk.\(kind.rawValue.lowercased())"),
            format: try PDKFoundationArtifactBridge.artifactFormat(for: format)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case assetID
        case role
        case path
        case kind
        case format
        case required
        case sha256
        case byteCount
        case cornerIDs
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assetID = try container.decode(String.self, forKey: .assetID)
        role = try container.decode(PDKAssetRole.self, forKey: .role)
        path = try container.decode(String.self, forKey: .path)
        kind = try container.decode(ArtifactKind.self, forKey: .kind)
        let rawFormat = try container.decode(String.self, forKey: .format)
        format = try ArtifactFormat(rawValue: rawFormat.lowercased())
        required = try container.decode(Bool.self, forKey: .required)
        sha256 = try container.decodeIfPresent(String.self, forKey: .sha256)
        byteCount = try container.decodeIfPresent(Int64.self, forKey: .byteCount)
        cornerIDs = try container.decode([String].self, forKey: .cornerIDs)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }
}
