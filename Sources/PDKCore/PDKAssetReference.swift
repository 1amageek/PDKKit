import Foundation
import XcircuitePackage

public struct PDKAssetReference: Sendable, Hashable, Codable {
    public var assetID: String
    public var role: PDKAssetRole
    public var path: String
    public var kind: XcircuiteFileKind
    public var format: XcircuiteFileFormat
    public var required: Bool
    public var sha256: String?
    public var byteCount: Int64?
    public var cornerIDs: [String]
    public var metadata: [String: String]

    public init(
        assetID: String,
        role: PDKAssetRole,
        path: String,
        kind: XcircuiteFileKind,
        format: XcircuiteFileFormat,
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

    public var fileReference: XcircuiteFileReference {
        XcircuiteFileReference(
            artifactID: assetID,
            path: path,
            kind: kind,
            format: format,
            sha256: sha256,
            byteCount: byteCount
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
        assetID = try container.decodeIfPresent(String.self, forKey: .assetID) ?? ""
        role = try container.decodeIfPresent(PDKAssetRole.self, forKey: .role) ?? .other
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        kind = try container.decodeIfPresent(XcircuiteFileKind.self, forKey: .kind) ?? .other
        format = try container.decodeIfPresent(XcircuiteFileFormat.self, forKey: .format) ?? .unknown
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? true
        sha256 = try container.decodeIfPresent(String.self, forKey: .sha256)
        byteCount = try container.decodeIfPresent(Int64.self, forKey: .byteCount)
        cornerIDs = try container.decodeIfPresent([String].self, forKey: .cornerIDs) ?? []
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
}
