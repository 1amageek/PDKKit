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
        let sourceSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        guard sourceSchemaVersion <= Self.currentSchemaVersion else {
            throw PDKManifestError.unsupportedSchemaVersion(sourceSchemaVersion)
        }

        schemaVersion = Self.currentSchemaVersion
        processID = try container.decodeIfPresent(String.self, forKey: .processID)
            ?? container.decodeIfPresent(String.self, forKey: .process)
            ?? ""
        version = try container.decodeIfPresent(String.self, forKey: .version)
            ?? container.decodeIfPresent(String.self, forKey: .pdkVersion)
            ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        if let currentAssets = try container.decodeIfPresent([PDKAssetReference].self, forKey: .assets) {
            assets = currentAssets
        } else {
            do {
                assets = try container.decodeIfPresent([PDKAssetReference].self, forKey: .files) ?? []
            } catch {
                guard sourceSchemaVersion == 0 else { throw error }
                let legacyPaths = try container.decode([String].self, forKey: .files)
                assets = legacyPaths.map { path in
                    PDKAssetReference(
                        assetID: URL(filePath: path).deletingPathExtension().lastPathComponent,
                        role: .other,
                        path: path,
                        kind: .other,
                        format: .unknown
                    )
                }
            }
        }
        layers = try container.decodeIfPresent([PDKLayerDefinition].self, forKey: .layers) ?? []
        devices = try container.decodeIfPresent([PDKDeviceDefinition].self, forKey: .devices) ?? []
        corners = try container.decodeIfPresent([PDKCornerDefinition].self, forKey: .corners) ?? []
        crossViewMappings = try container.decodeIfPresent(
            [PDKCrossViewMapping].self,
            forKey: .crossViewMappings
        ) ?? []
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
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

    public func qualificationScope(
        pdkDigest: String,
        assetDigests: [String: String] = [:]
    ) -> PDKQualificationScope {
        let capabilities = Set(crossViewMappings.map { $0.view.rawValue })
        return PDKQualificationScope(
            scopeID: "\(processID)@\(version):\(pdkDigest)",
            processID: processID,
            version: version,
            pdkDigest: pdkDigest,
            capabilityIDs: capabilities.sorted(),
            layerIDs: layers.map(\.layerID).sorted(),
            deviceIDs: devices.map(\.deviceID).sorted(),
            cornerIDs: corners.map(\.cornerID).sorted(),
            assetDigests: assetDigests,
            limitations: [
                "Qualification state is unverified until corpus and oracle evidence are attached."
            ]
        )
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
        case process
        case version
        case pdkVersion
        case displayName
        case assets
        case files
        case layers
        case devices
        case corners
        case crossViewMappings
        case metadata
    }
}
