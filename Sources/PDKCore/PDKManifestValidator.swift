import Foundation

public struct PDKManifestValidator: Sendable {
    public init() {}

    public func validate(_ manifest: PDKManifest) -> PDKManifestValidationReport {
        validate(manifest, construction: { _ in })
    }

    package func validate(_ manifest: PDKManifest,
        construction: (PDKManifestValidationEvent) throws -> Void) rethrows -> PDKManifestValidationReport {
        try construction(.checkpoint)
        var findings: [PDKValidationFinding] = []
        if manifest.schemaVersion != PDKManifest.currentSchemaVersion {
            try append(blocker(
                "pdk.manifest.unsupported-schema-version",
                "Manifest schema version is not the current supported version.",
                "schemaVersion"
            ), findings: &findings, construction: construction)
        }
        try requireNonEmpty(manifest.processID, field: "processID", findings: &findings, construction: construction)
        try requireNonEmpty(manifest.version, field: "version", findings: &findings, construction: construction)
        try validateUnique(
            try project(manifest.assets, \.assetID, construction: construction),
            code: "pdk.manifest.duplicate-asset-id",
            entity: "assets",
            findings: &findings, construction: construction
        )
        try validateUnique(
            try project(manifest.layers, \.layerID, construction: construction),
            code: "pdk.manifest.duplicate-layer-id",
            entity: "layers",
            findings: &findings, construction: construction
        )
        try validateUnique(
            try project(manifest.devices, \.deviceID, construction: construction),
            code: "pdk.manifest.duplicate-device-id",
            entity: "devices",
            findings: &findings, construction: construction
        )
        try validateUnique(
            try project(manifest.corners, \.cornerID, construction: construction),
            code: "pdk.manifest.duplicate-corner-id",
            entity: "corners",
            findings: &findings, construction: construction
        )
        try validateUnique(
            try project(manifest.crossViewMappings, \.mappingID, construction: construction),
            code: "pdk.manifest.duplicate-mapping-id",
            entity: "crossViewMappings",
            findings: &findings, construction: construction
        )

        if manifest.assets.isEmpty {
            try append(blocker("pdk.manifest.assets-missing", "Manifest declares no PDK assets.", "assets"), findings: &findings, construction: construction)
        }
        if manifest.layers.isEmpty {
            try append(blocker("pdk.manifest.layers-missing", "Manifest declares no manufacturing layers.", "layers"), findings: &findings, construction: construction)
        }
        if manifest.devices.isEmpty {
            try append(blocker("pdk.manifest.devices-missing", "Manifest declares no device semantics.", "devices"), findings: &findings, construction: construction)
        }
        if manifest.corners.isEmpty {
            try append(blocker("pdk.manifest.corners-missing", "Manifest declares no PVT or signoff corners.", "corners"), findings: &findings, construction: construction)
        }
        if manifest.crossViewMappings.isEmpty {
            try append(blocker(
                "pdk.manifest.cross-view-semantics-missing",
                "Cross-view mappings are required; raw files alone do not establish semantic consistency.",
                "crossViewMappings"
            ), findings: &findings, construction: construction)
        }

        let assetIDs = try identifiers(try project(manifest.assets, \.assetID, construction: construction), construction: construction)
        let layerIDs = try identifiers(try project(manifest.layers, \.layerID, construction: construction), construction: construction)
        let deviceIDs = try identifiers(try project(manifest.devices, \.deviceID, construction: construction), construction: construction)
        let cornerIDs = try identifiers(try project(manifest.corners, \.cornerID, construction: construction), construction: construction)

        for asset in manifest.assets {
            try construction(.checkpoint)
            if asset.assetID.isEmpty {
                try append(blocker("pdk.manifest.asset-id-missing", "Asset ID must not be empty.", "assets"), findings: &findings, construction: construction)
            }
            if asset.path.isEmpty {
                try append(blocker("pdk.manifest.asset-path-missing", "Asset path must not be empty.", asset.assetID), findings: &findings, construction: construction)
            }
            if asset.path.hasPrefix("/") {
                try append(PDKValidationFinding(
                    severity: .warning,
                    code: "pdk.manifest.absolute-asset-path",
                    message: "Absolute asset paths reduce portability and reproducibility.",
                    entity: asset.assetID,
                    suggestedActions: ["use_manifest_relative_path"]
                ), findings: &findings, construction: construction)
            }
            for cornerID in asset.cornerIDs where !(try contains(cornerIDs, cornerID, construction: construction)) {
                try append(blocker(
                    "pdk.manifest.asset-corner-reference-missing",
                    "Asset references an unknown corner.",
                    try joined(asset.assetID, cornerID, construction: construction)
                ), findings: &findings, construction: construction)
            }
        }

        for layer in manifest.layers {
            try construction(.checkpoint)
            if layer.name.isEmpty || layer.number <= 0 {
                try append(blocker(
                    "pdk.manifest.invalid-layer",
                    "Layer name and positive manufacturing number are required.",
                    layer.layerID
                ), findings: &findings, construction: construction)
            }
            if let width = layer.minimumWidth, width <= 0 {
                try append(blocker("pdk.manifest.invalid-layer-width", "Minimum width must be positive.", layer.layerID), findings: &findings, construction: construction)
            }
            if let spacing = layer.minimumSpacing, spacing <= 0 {
                try append(blocker("pdk.manifest.invalid-layer-spacing", "Minimum spacing must be positive.", layer.layerID), findings: &findings, construction: construction)
            }
        }

        for device in manifest.devices {
            try construction(.checkpoint)
            if device.modelName.isEmpty || device.terminals.isEmpty {
                try append(blocker(
                    "pdk.manifest.invalid-device",
                    "Device model name and at least one terminal are required.",
                    device.deviceID
                ), findings: &findings, construction: construction)
            }
            let terminalNames = try project(device.terminals, \.name, construction: construction)
            try validateUnique(
                terminalNames,
                code: "pdk.manifest.duplicate-terminal",
                entity: device.deviceID,
                findings: &findings, construction: construction
            )
            if let recognition = device.extractionRecognition {
                for layerID in recognition.layerIDs where !(try contains(layerIDs, layerID, construction: construction)) {
                    try append(blocker(
                        "pdk.manifest.extraction-layer-reference-missing",
                        "Extraction recognition references an unknown layer.",
                        try joined(device.deviceID, layerID, construction: construction)
                    ), findings: &findings, construction: construction)
                }
                if recognition.layerIDs.isEmpty && recognition.markerNames.isEmpty && recognition.extractorKeys.isEmpty {
                    try append(blocker(
                        "pdk.manifest.extraction-recognition-empty",
                        "Extraction recognition must identify at least one layer, marker or extractor key.",
                        device.deviceID
                    ), findings: &findings, construction: construction)
                }
            }
        }

        for corner in manifest.corners {
            try construction(.checkpoint)
            if corner.pvt.voltage <= 0 {
                try append(blocker("pdk.manifest.invalid-corner-voltage", "Corner voltage must be positive.", corner.cornerID), findings: &findings, construction: construction)
            }
            for assetID in corner.assetIDs where !(try contains(assetIDs, assetID, construction: construction)) {
                try append(blocker(
                    "pdk.manifest.corner-asset-reference-missing",
                    "Corner references an unknown asset.",
                    try joined(corner.cornerID, assetID, construction: construction)
                ), findings: &findings, construction: construction)
            }
            for (view, assetID) in corner.viewMappings where !(try contains(assetIDs, assetID, construction: construction)) {
                try append(blocker(
                    "pdk.manifest.corner-view-reference-missing",
                    "Corner view mapping references an unknown asset.",
                    try joined(corner.cornerID, view, construction: construction)
                ), findings: &findings, construction: construction)
            }
        }

        for mapping in manifest.crossViewMappings {
            try construction(.checkpoint)
            if !(try contains(assetIDs, mapping.assetID, construction: construction)) {
                try append(blocker(
                    "pdk.manifest.mapping-asset-reference-missing",
                    "Cross-view mapping references an unknown asset.",
                    mapping.mappingID
                ), findings: &findings, construction: construction)
            }
            for layerID in mapping.layerIDs where !(try contains(layerIDs, layerID, construction: construction)) {
                try append(blocker(
                    "pdk.manifest.mapping-layer-reference-missing",
                    "Cross-view mapping references an unknown layer.",
                    try joined(mapping.mappingID, layerID, construction: construction)
                ), findings: &findings, construction: construction)
            }
            for deviceID in mapping.deviceIDs where !(try contains(deviceIDs, deviceID, construction: construction)) {
                try append(blocker(
                    "pdk.manifest.mapping-device-reference-missing",
                    "Cross-view mapping references an unknown device.",
                    try joined(mapping.mappingID, deviceID, construction: construction)
                ), findings: &findings, construction: construction)
            }
            for cornerID in mapping.cornerIDs where !(try contains(cornerIDs, cornerID, construction: construction)) {
                try append(blocker(
                    "pdk.manifest.mapping-corner-reference-missing",
                    "Cross-view mapping references an unknown corner.",
                    try joined(mapping.mappingID, cornerID, construction: construction)
                ), findings: &findings, construction: construction)
            }
        }

        try construction(.work(findings.count))
        let isValid = !findings.contains { $0.severity == .blocker || $0.severity == .error }
        try construction(.checkpoint)
        return PDKManifestValidationReport(isValid: isValid, findings: findings)
    }

    private func requireNonEmpty(_ value: String, field: String, findings: inout [PDKValidationFinding],
        construction: (PDKManifestValidationEvent) throws -> Void) rethrows {
        try construction(.inspect(value))
        // Trimming can return a new String; its output cannot exceed the input UTF-8 length.
        try construction(.temporaryText(value.utf8.count))
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try construction(.retainedText("pdk.manifest.".utf8.count + field.utf8.count + "-missing".utf8.count))
            try construction(.retainedText(field.utf8.count + " must not be empty.".utf8.count))
            try append(blocker("pdk.manifest.\(field)-missing", "\(field) must not be empty.", field),
                findings: &findings, construction: construction)
        }
    }

    private func validateUnique(_ values: [String], code: String, entity: String,
        findings: inout [PDKValidationFinding], construction: (PDKManifestValidationEvent) throws -> Void) rethrows {
        try construction(.identifierSet(values.count))
        var seen = Set<String>(minimumCapacity: values.count)
        for value in values {
            try construction(.inspect(value))
            if !seen.insert(value).inserted {
                try append(blocker(code, "Identifier must be unique.", try joined(entity, value, construction: construction)),
                    findings: &findings, construction: construction)
            }
        }
    }

    private func project<Value>(_ values: [Value], _ key: KeyPath<Value, String>,
        construction: (PDKManifestValidationEvent) throws -> Void) rethrows -> [String] {
        try construction(.projection(values.count))
        var result: [String] = []
        result.reserveCapacity(values.count)
        for value in values {
            try construction(.checkpoint)
            result.append(value[keyPath: key])
        }
        return result
    }

    private func identifiers(_ values: [String],
        construction: (PDKManifestValidationEvent) throws -> Void) rethrows -> Set<String> {
        try construction(.identifierSet(values.count))
        var result = Set<String>(minimumCapacity: values.count)
        for value in values {
            try construction(.inspect(value))
            result.insert(value)
        }
        return result
    }

    private func contains(_ values: Set<String>, _ value: String,
        construction: (PDKManifestValidationEvent) throws -> Void) rethrows -> Bool {
        try construction(.inspect(value))
        return values.contains(value)
    }

    private func joined(_ first: String, _ second: String,
        construction: (PDKManifestValidationEvent) throws -> Void) rethrows -> String {
        try construction(.inspect(first))
        try construction(.inspect(second))
        // The event handler performs checked addition before this interpolation.
        try construction(.joinedEntity(first.utf8.count, second.utf8.count))
        return "\(first):\(second)"
    }

    private func append(_ finding: @autoclosure () throws -> PDKValidationFinding,
        findings: inout [PDKValidationFinding], construction: (PDKManifestValidationEvent) throws -> Void) rethrows {
        try construction(.checkpoint)
        if findings.count == findings.capacity {
            try construction(.findingGrowth(findings.capacity))
            findings.reserveCapacity(max(findings.capacity, 1) * 2)
        }
        try construction(.findingActions)
        let value = try finding()
        try construction(.diagnostic(value))
        findings.append(value)
    }

    private func blocker(_ code: String, _ message: String, _ entity: String?) -> PDKValidationFinding {
        PDKValidationFinding(severity: .blocker, code: code, message: message,
            entity: entity, suggestedActions: ["update_pdk_manifest"])
    }
}
