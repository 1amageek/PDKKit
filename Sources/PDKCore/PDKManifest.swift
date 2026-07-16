import Foundation

public struct PDKManifest: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1
    public static let fileName = "pdk.json"

    public var schemaVersion: Int
    public var processID: String
    public var version: String
    public var displayName: String?
    public var assets: [PDKAssetReference]
    public var layers: [PDKLayerDefinition]
    public var devices: [PDKDeviceDefinition]
    public var corners: [PDKCornerDefinition]
    public var crossViewMappings: [PDKCrossViewMapping]
    public var metadata: [String: String]

    public init(
        processID: String,
        version: String,
        displayName: String? = nil,
        assets: [PDKAssetReference] = [],
        layers: [PDKLayerDefinition] = [],
        devices: [PDKDeviceDefinition] = [],
        corners: [PDKCornerDefinition] = [],
        crossViewMappings: [PDKCrossViewMapping] = [],
        metadata: [String: String] = [:]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.processID = processID
        self.version = version
        self.displayName = displayName
        self.assets = assets
        self.layers = layers
        self.devices = devices
        self.corners = corners
        self.crossViewMappings = crossViewMappings
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard decodedSchemaVersion == Self.currentSchemaVersion else {
            throw PDKManifestError.unsupportedSchemaVersion(decodedSchemaVersion)
        }

        schemaVersion = decodedSchemaVersion
        processID = try container.decode(String.self, forKey: .processID)
        version = try container.decode(String.self, forKey: .version)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        assets = try container.decode([PDKAssetReference].self, forKey: .assets)
        layers = try container.decode([PDKLayerDefinition].self, forKey: .layers)
        devices = try container.decode([PDKDeviceDefinition].self, forKey: .devices)
        corners = try container.decode([PDKCornerDefinition].self, forKey: .corners)
        crossViewMappings = try container.decode([PDKCrossViewMapping].self, forKey: .crossViewMappings)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(processID, forKey: .processID)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encode(assets, forKey: .assets)
        try container.encode(layers, forKey: .layers)
        try container.encode(devices, forKey: .devices)
        try container.encode(corners, forKey: .corners)
        try container.encode(crossViewMappings, forKey: .crossViewMappings)
        try container.encode(metadata, forKey: .metadata)
    }

    public func validate() -> PDKManifestValidationReport {
        PDKManifestValidator().validate(self)
    }

    public func capabilityReport(
        pdkDigest: String,
        resolvedAssetIDs: Set<String>? = nil
    ) -> PDKCapabilityReport {
        let assetIDs = Set(assets.map(\.assetID))
        let availableAssets = resolvedAssetIDs ?? []
        let assetIntegrityStatus: PDKCapabilityStatus
        if resolvedAssetIDs == nil {
            assetIntegrityStatus = .notEvaluated
        } else {
            assetIntegrityStatus = availableAssets.count == assetIDs.count ? .available : .blocked
        }
        let capabilities = [
            PDKCapability(
                capabilityID: "manifest.identity",
                status: processID.isEmpty || version.isEmpty ? .blocked : .available
            ),
            PDKCapability(
                capabilityID: "semantics.layers",
                status: layers.isEmpty ? .blocked : .available,
                evidenceAssetIDs: crossViewMappings.filter { $0.view == .layerMap }.map(\.assetID)
            ),
            PDKCapability(
                capabilityID: "semantics.devices",
                status: devices.isEmpty ? .blocked : .available,
                evidenceAssetIDs: crossViewMappings.filter { $0.view == .spice }.map(\.assetID)
            ),
            PDKCapability(
                capabilityID: "semantics.corners",
                status: corners.isEmpty ? .blocked : .available
            ),
            PDKCapability(
                capabilityID: "cross-view.mapping",
                status: crossViewMappings.isEmpty ? .blocked : .available,
                evidenceAssetIDs: crossViewMappings.map(\.assetID)
            ),
            PDKCapability(
                capabilityID: "assets.integrity",
                status: assetIntegrityStatus,
                evidenceAssetIDs: availableAssets.sorted(),
                limitation: assetIntegrityStatus == .available ? nil : "Asset integrity was not fully established."
            ),
        ]
        return PDKCapabilityReport(
            processID: processID,
            version: version,
            pdkDigest: pdkDigest,
            capabilities: capabilities,
            limitations: [
                "Capability availability is not foundry qualification.",
                "Oracle correlation and process-scoped qualification evidence must be attached by ToolQualification."
            ]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case processID
        case version
        case displayName
        case assets
        case layers
        case devices
        case corners
        case crossViewMappings
        case metadata
    }
}
