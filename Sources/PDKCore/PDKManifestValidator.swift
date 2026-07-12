import Foundation

public struct PDKManifestValidator: Sendable {
    public init() {}

    public func validate(_ manifest: PDKManifest) -> PDKManifestValidationReport {
        var findings: [PDKValidationFinding] = []
        if manifest.schemaVersion != PDKManifest.currentSchemaVersion {
            findings.append(blocker(
                "pdk.manifest.unsupported-schema-version",
                "Manifest schema version is not the current supported version.",
                "schemaVersion"
            ))
        }
        requireNonEmpty(manifest.processID, field: "processID", findings: &findings)
        requireNonEmpty(manifest.version, field: "version", findings: &findings)
        validateUnique(
            manifest.assets.map(\.assetID),
            code: "pdk.manifest.duplicate-asset-id",
            entity: "assets",
            findings: &findings
        )
        validateUnique(
            manifest.layers.map(\.layerID),
            code: "pdk.manifest.duplicate-layer-id",
            entity: "layers",
            findings: &findings
        )
        validateUnique(
            manifest.devices.map(\.deviceID),
            code: "pdk.manifest.duplicate-device-id",
            entity: "devices",
            findings: &findings
        )
        validateUnique(
            manifest.corners.map(\.cornerID),
            code: "pdk.manifest.duplicate-corner-id",
            entity: "corners",
            findings: &findings
        )
        validateUnique(
            manifest.crossViewMappings.map(\.mappingID),
            code: "pdk.manifest.duplicate-mapping-id",
            entity: "crossViewMappings",
            findings: &findings
        )

        if manifest.assets.isEmpty {
            findings.append(blocker("pdk.manifest.assets-missing", "Manifest declares no PDK assets.", "assets"))
        }
        if manifest.layers.isEmpty {
            findings.append(blocker("pdk.manifest.layers-missing", "Manifest declares no manufacturing layers.", "layers"))
        }
        if manifest.devices.isEmpty {
            findings.append(blocker("pdk.manifest.devices-missing", "Manifest declares no device semantics.", "devices"))
        }
        if manifest.corners.isEmpty {
            findings.append(blocker("pdk.manifest.corners-missing", "Manifest declares no PVT or signoff corners.", "corners"))
        }
        if manifest.crossViewMappings.isEmpty {
            findings.append(blocker(
                "pdk.manifest.cross-view-semantics-missing",
                "Cross-view mappings are required; raw files alone do not establish semantic consistency.",
                "crossViewMappings"
            ))
        }

        let assetIDs = Set(manifest.assets.map(\.assetID))
        let layerIDs = Set(manifest.layers.map(\.layerID))
        let deviceIDs = Set(manifest.devices.map(\.deviceID))
        let cornerIDs = Set(manifest.corners.map(\.cornerID))

        for asset in manifest.assets {
            if asset.assetID.isEmpty {
                findings.append(blocker("pdk.manifest.asset-id-missing", "Asset ID must not be empty.", "assets"))
            }
            if asset.path.isEmpty {
                findings.append(blocker("pdk.manifest.asset-path-missing", "Asset path must not be empty.", asset.assetID))
            }
            if asset.path.hasPrefix("/") {
                findings.append(PDKValidationFinding(
                    severity: .warning,
                    code: "pdk.manifest.absolute-asset-path",
                    message: "Absolute asset paths reduce portability and reproducibility.",
                    entity: asset.assetID,
                    suggestedActions: ["use_manifest_relative_path"]
                ))
            }
            for cornerID in asset.cornerIDs where !cornerIDs.contains(cornerID) {
                findings.append(blocker(
                    "pdk.manifest.asset-corner-reference-missing",
                    "Asset references an unknown corner.",
                    "\(asset.assetID):\(cornerID)"
                ))
            }
        }

        for layer in manifest.layers {
            if layer.name.isEmpty || layer.number <= 0 {
                findings.append(blocker(
                    "pdk.manifest.invalid-layer",
                    "Layer name and positive manufacturing number are required.",
                    layer.layerID
                ))
            }
            if let width = layer.minimumWidth, width <= 0 {
                findings.append(blocker("pdk.manifest.invalid-layer-width", "Minimum width must be positive.", layer.layerID))
            }
            if let spacing = layer.minimumSpacing, spacing <= 0 {
                findings.append(blocker("pdk.manifest.invalid-layer-spacing", "Minimum spacing must be positive.", layer.layerID))
            }
        }

        for device in manifest.devices {
            if device.modelName.isEmpty || device.terminals.isEmpty {
                findings.append(blocker(
                    "pdk.manifest.invalid-device",
                    "Device model name and at least one terminal are required.",
                    device.deviceID
                ))
            }
            let terminalNames = device.terminals.map(\.name)
            validateUnique(
                terminalNames,
                code: "pdk.manifest.duplicate-terminal",
                entity: device.deviceID,
                findings: &findings
            )
            if let recognition = device.extractionRecognition {
                for layerID in recognition.layerIDs where !layerIDs.contains(layerID) {
                    findings.append(blocker(
                        "pdk.manifest.extraction-layer-reference-missing",
                        "Extraction recognition references an unknown layer.",
                        "\(device.deviceID):\(layerID)"
                    ))
                }
                if recognition.layerIDs.isEmpty && recognition.markerNames.isEmpty && recognition.extractorKeys.isEmpty {
                    findings.append(blocker(
                        "pdk.manifest.extraction-recognition-empty",
                        "Extraction recognition must identify at least one layer, marker or extractor key.",
                        device.deviceID
                    ))
                }
            }
        }

        for corner in manifest.corners {
            if corner.pvt.voltage <= 0 {
                findings.append(blocker("pdk.manifest.invalid-corner-voltage", "Corner voltage must be positive.", corner.cornerID))
            }
            for assetID in corner.assetIDs where !assetIDs.contains(assetID) {
                findings.append(blocker(
                    "pdk.manifest.corner-asset-reference-missing",
                    "Corner references an unknown asset.",
                    "\(corner.cornerID):\(assetID)"
                ))
            }
            for (view, assetID) in corner.viewMappings where !assetIDs.contains(assetID) {
                findings.append(blocker(
                    "pdk.manifest.corner-view-reference-missing",
                    "Corner view mapping references an unknown asset.",
                    "\(corner.cornerID):\(view)"
                ))
            }
        }

        for mapping in manifest.crossViewMappings {
            if !assetIDs.contains(mapping.assetID) {
                findings.append(blocker(
                    "pdk.manifest.mapping-asset-reference-missing",
                    "Cross-view mapping references an unknown asset.",
                    mapping.mappingID
                ))
            }
            for layerID in mapping.layerIDs where !layerIDs.contains(layerID) {
                findings.append(blocker(
                    "pdk.manifest.mapping-layer-reference-missing",
                    "Cross-view mapping references an unknown layer.",
                    "\(mapping.mappingID):\(layerID)"
                ))
            }
            for deviceID in mapping.deviceIDs where !deviceIDs.contains(deviceID) {
                findings.append(blocker(
                    "pdk.manifest.mapping-device-reference-missing",
                    "Cross-view mapping references an unknown device.",
                    "\(mapping.mappingID):\(deviceID)"
                ))
            }
            for cornerID in mapping.cornerIDs where !cornerIDs.contains(cornerID) {
                findings.append(blocker(
                    "pdk.manifest.mapping-corner-reference-missing",
                    "Cross-view mapping references an unknown corner.",
                    "\(mapping.mappingID):\(cornerID)"
                ))
            }
        }

        let isValid = !findings.contains { $0.severity == .blocker || $0.severity == .error }
        return PDKManifestValidationReport(isValid: isValid, findings: findings)
    }

    private func requireNonEmpty(_ value: String, field: String, findings: inout [PDKValidationFinding]) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(blocker("pdk.manifest.\(field)-missing", "\(field) must not be empty.", field))
        }
    }

    private func validateUnique(
        _ values: [String],
        code: String,
        entity: String,
        findings: inout [PDKValidationFinding]
    ) {
        var seen = Set<String>()
        for value in values where !seen.insert(value).inserted {
            findings.append(blocker(code, "Identifier must be unique.", "\(entity):\(value)"))
        }
    }

    private func blocker(_ code: String, _ message: String, _ entity: String?) -> PDKValidationFinding {
        PDKValidationFinding(
            severity: .blocker,
            code: code,
            message: message,
            entity: entity,
            suggestedActions: ["update_pdk_manifest"]
        )
    }
}
