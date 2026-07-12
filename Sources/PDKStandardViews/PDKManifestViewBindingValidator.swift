import Foundation
import PDKCore

public struct PDKManifestViewBindingValidator: Sendable {
    public init() {}

    public func validate(
        manifest: PDKManifest,
        assetID: String,
        format: PDKStandardViewFormat,
        inspection: PDKStandardViewIR
    ) -> PDKStandardViewBindingReport {
        var findings: [PDKValidationFinding] = []
        guard let mapping = manifest.crossViewMappings.first(where: {
            $0.assetID == assetID && $0.view == format.manifestView
        }) else {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.cross-view-mapping-missing",
                message: "No manifest cross-view mapping exists for the inspected asset and format.",
                entity: assetID,
                suggestedActions: ["add_cross_view_mapping", "repair_pdk_manifest"]
            )
            return PDKStandardViewBindingReport(
                isValid: false,
                expectedLayerNames: [],
                observedLayerNames: inspection.layerNames,
                expectedPhysicalLayerNumbers: [],
                observedPhysicalLayerNumbers: inspection.physicalLayerNumbers,
                expectedCellNames: [],
                observedCellNames: inspection.cellNames,
                findings: [finding]
            )
        }

        let expectedLayerDefinitions = mapping.layerIDs.compactMap { layerID in
            manifest.layers.first { $0.layerID == layerID }
        }
        let missingLayerDefinitions = mapping.layerIDs.filter { layerID in
            !manifest.layers.contains { $0.layerID == layerID }
        }
        if !missingLayerDefinitions.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.mapping-layer-definition-missing",
                message: "Cross-view mapping references unknown manifest layers: \(missingLayerDefinitions.joined(separator: ", ")).",
                entity: mapping.mappingID,
                suggestedActions: ["repair_cross_view_mapping", "repair_pdk_manifest"]
            ))
        }

        let expectedLayerNames = expectedLayerDefinitions.map(\.name)
        let expectedPhysicalLayerNumbers = expectedLayerDefinitions.map(\.number)
        let missingLayerNames: [String]
        let missingPhysicalLayerNumbers: [Int]
        switch format {
        case .lef:
            missingLayerNames = expectedLayerDefinitions.compactMap { definition in
                let candidates = [definition.name] + definition.aliases
                return candidates.contains(where: { candidate in
                    inspection.layerNames.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
                }) ? nil : definition.name
            }
            missingPhysicalLayerNumbers = []
        case .gdsii, .oasis:
            missingLayerNames = []
            missingPhysicalLayerNumbers = expectedLayerDefinitions.compactMap { definition in
                inspection.physicalLayerNumbers.contains(definition.number) ? nil : definition.number
            }
        case .spice, .liberty:
            missingLayerNames = []
            missingPhysicalLayerNumbers = []
        }
        if !missingLayerNames.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.layer-binding-missing",
                message: "Manifest layer names are absent from the parsed view: \(missingLayerNames.joined(separator: ", ")).",
                entity: mapping.mappingID,
                suggestedActions: ["repair_standard_view_layers", "repair_cross_view_mapping"]
            ))
        }
        if !missingPhysicalLayerNumbers.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.physical-layer-binding-missing",
                message: "Manifest physical layer numbers are absent from the parsed view: \(missingPhysicalLayerNumbers.map(String.init).joined(separator: ", ")).",
                entity: mapping.mappingID,
                suggestedActions: ["repair_layer_map", "repair_standard_view_layers"]
            ))
        }

        let expectedDevices = mapping.deviceIDs.compactMap { deviceID in
            manifest.devices.first { $0.deviceID == deviceID }
        }
        let missingDeviceDefinitions = mapping.deviceIDs.filter { deviceID in
            !manifest.devices.contains { $0.deviceID == deviceID }
        }
        if !missingDeviceDefinitions.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.mapping-device-definition-missing",
                message: "Cross-view mapping references unknown manifest devices: \(missingDeviceDefinitions.joined(separator: ", ")).",
                entity: mapping.mappingID,
                suggestedActions: ["repair_cross_view_mapping", "repair_pdk_manifest"]
            ))
        }
        let expectedCellNames = expectedDevices.map(\.deviceID)
        let missingCellNames = expectedDevices.compactMap { device in
            let candidates = [device.deviceID, device.modelName] + device.aliases
            let observedNames = format == .spice
                ? inspection.cellNames + inspection.modelNames
                : inspection.cellNames
            return candidates.contains(where: { candidate in
                observedNames.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
            }) ? nil : device.deviceID
        }
        if !missingCellNames.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.cell-binding-missing",
                message: "Manifest device names are absent from the parsed view: \(missingCellNames.joined(separator: ", ")).",
                entity: mapping.mappingID,
                suggestedActions: ["repair_standard_view_cells", "repair_cross_view_mapping"]
            ))
        }

        let expectedCorners = mapping.cornerIDs.compactMap { cornerID in
            manifest.corners.first { $0.cornerID == cornerID }
        }
        let missingCornerDefinitions = mapping.cornerIDs.filter { cornerID in
            !manifest.corners.contains { $0.cornerID == cornerID }
        }
        if !missingCornerDefinitions.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.mapping-corner-definition-missing",
                message: "Cross-view mapping references unknown manifest corners: \(missingCornerDefinitions.joined(separator: ", ")).",
                entity: mapping.mappingID,
                suggestedActions: ["repair_cross_view_mapping", "repair_pdk_manifest"]
            ))
        }
        let expectedCornerNames = expectedCorners.map(\.cornerID)
        let observedCornerNames = inspection.cornerNames
        let missingCornerNames = expectedCorners.compactMap { corner in
            let candidates = [
                corner.cornerID,
                corner.pvt.process.name,
                corner.rcCorner,
                corner.electromigrationCorner,
                corner.reliabilityCorner
            ].compactMap { $0 }
            return candidates.contains(where: { candidate in
                observedCornerNames.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
            }) ? nil : corner.cornerID
        }
        if !missingCornerNames.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.corner-binding-missing",
                message: "Manifest corner names are absent from the parsed view: \(missingCornerNames.joined(separator: ", ")).",
                entity: mapping.mappingID,
                suggestedActions: ["repair_standard_view_corners", "repair_cross_view_mapping"]
            ))
        }

        return PDKStandardViewBindingReport(
            isValid: !findings.contains { $0.severity == .blocker || $0.severity == .error },
            mappingID: mapping.mappingID,
            expectedLayerNames: expectedLayerNames,
            observedLayerNames: inspection.layerNames,
            missingLayerNames: missingLayerNames,
            expectedPhysicalLayerNumbers: expectedPhysicalLayerNumbers,
            observedPhysicalLayerNumbers: inspection.physicalLayerNumbers,
            missingPhysicalLayerNumbers: missingPhysicalLayerNumbers,
            expectedCellNames: expectedCellNames,
            observedCellNames: format == .spice
                ? inspection.cellNames + inspection.modelNames
                : inspection.cellNames,
            missingCellNames: missingCellNames,
            expectedCornerNames: expectedCornerNames,
            observedCornerNames: observedCornerNames,
            missingCornerNames: missingCornerNames,
            findings: findings
        )
    }
}
