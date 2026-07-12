import Foundation
import PDKCore
import XcircuitePackage

public struct LocalPDKValidator: PDKValidating {
    private let clock: any PDKValidationExecutionClock
    private let assetResolver: any PDKAssetResolving
    private let digestor: any PDKDigesting
    private let manifestValidator: PDKManifestValidator

    public init(
        clock: any PDKValidationExecutionClock = SystemPDKValidationExecutionClock(),
        assetResolver: any PDKAssetResolving = LocalPDKAssetResolver(),
        digestor: any PDKDigesting = SHA256PDKDigestor(),
        manifestValidator: PDKManifestValidator = PDKManifestValidator()
    ) {
        self.clock = clock
        self.assetResolver = assetResolver
        self.digestor = digestor
        self.manifestValidator = manifestValidator
    }

    public func execute(
        _ request: PDKValidationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKValidationPayload> {
        let startedAt = clock.now()
        let manifestURL = URL(filePath: request.pdk.manifest.path).standardizedFileURL
        let result = validate(request: request, manifestURL: manifestURL)
        let completedAt = clock.now()
        let metadata = XcircuiteEngineExecutionMetadata(
            engineID: "PDKValidation",
            implementationID: "LocalPDKValidator",
            implementationVersion: "1",
            startedAt: startedAt,
            completedAt: completedAt
        )
        return XcircuiteEngineResultEnvelope(
            schemaVersion: PDKValidationRequest.currentSchemaVersion,
            runID: request.runID,
            status: result.status,
            diagnostics: result.diagnostics,
            artifacts: result.resolvedAssets.map(\.reference),
            metadata: metadata,
            payload: PDKValidationPayload(
                isValid: result.status == .completed,
                missingRequirements: result.missingRequirements,
                findings: result.findings,
                resolvedAssets: result.resolvedAssets,
                qualificationScope: result.qualificationScope,
                capabilityReport: result.capabilityReport
            )
        )
    }

    private func validate(
        request: PDKValidationRequest,
        manifestURL: URL
    ) -> ValidationResult {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.manifest-missing",
                message: "PDK manifest does not exist at the referenced path.",
                entity: manifestURL.path,
                suggestedActions: ["restore_pdk_manifest", "update_manifest_reference"]
            )
            return result(status: .blocked, findings: [finding], request: request)
        }

        let decoded: PDKManifestMigrationResult
        do {
            decoded = try PDKManifestCodec.decode(contentsOf: manifestURL)
        } catch {
            let finding = PDKValidationFinding(
                severity: .error,
                code: "pdk.validation.manifest-decode-failed",
                message: "PDK manifest could not be decoded: \(error)",
                entity: manifestURL.path,
                suggestedActions: ["repair_manifest_json", "run_pdkkit_inspect"]
            )
            return result(status: .failed, findings: [finding], request: request)
        }

        var findings = manifestValidator.validate(decoded.manifest).findings
        validateInputs(request.inputs, findings: &findings)
        if decoded.wasMigrated {
            findings.append(PDKValidationFinding(
                severity: .warning,
                code: "pdk.validation.manifest-migrated",
                message: "Manifest was migrated from schema version \(decoded.sourceSchemaVersion) to \(decoded.targetSchemaVersion).",
                entity: manifestURL.path,
                suggestedActions: ["persist_current_manifest_schema"]
            ))
        }

        if request.pdk.processID != decoded.manifest.processID {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.process-id-mismatch",
                message: "PDK reference process ID does not match the manifest.",
                entity: "processID",
                suggestedActions: ["rebuild_pdk_reference"]
            ))
        }
        if request.pdk.version != decoded.manifest.version {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.version-mismatch",
                message: "PDK reference version does not match the manifest.",
                entity: "version",
                suggestedActions: ["rebuild_pdk_reference"]
            ))
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let actualDigest = try digestor.digest(data: data)
            if request.pdk.digest != actualDigest {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.validation.manifest-digest-mismatch",
                    message: "PDK reference digest does not match the manifest bytes.",
                    entity: manifestURL.path,
                    suggestedActions: ["rebuild_pdk_reference", "check_immutable_artifact"]
                ))
            }
        } catch {
            findings.append(PDKValidationFinding(
                severity: .error,
                code: "pdk.validation.manifest-read-failed",
                message: "PDK manifest bytes could not be read for digest verification: \(error.localizedDescription)",
                entity: manifestURL.path,
                suggestedActions: ["check_file_permissions"]
            ))
        }

        for role in request.requiredAssetRoles where !decoded.manifest.assets.contains(where: { $0.role == role }) {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.required-asset-role-missing",
                message: "No asset with the required role is declared.",
                entity: role.rawValue,
                suggestedActions: ["add_required_pdk_asset"]
            ))
        }

        var resolvedAssets: [PDKResolvedAsset] = []
        for asset in decoded.manifest.assets {
            do {
                let resolved = try assetResolver.resolve(asset, relativeTo: manifestURL)
                resolvedAssets.append(resolved)
                if let expected = asset.sha256, expected.lowercased() != resolved.computedSHA256 {
                    findings.append(PDKValidationFinding(
                        severity: .blocker,
                        code: "pdk.validation.asset-digest-mismatch",
                        message: "Asset digest does not match the manifest declaration.",
                        entity: asset.assetID,
                        suggestedActions: ["refresh_asset_digest", "check_immutable_artifact"]
                    ))
                }
                if let expected = asset.byteCount, expected != resolved.computedByteCount {
                    findings.append(PDKValidationFinding(
                        severity: .blocker,
                        code: "pdk.validation.asset-size-mismatch",
                        message: "Asset byte count does not match the manifest declaration.",
                        entity: asset.assetID,
                        suggestedActions: ["refresh_asset_metadata"]
                    ))
                }
            } catch {
                let severity: PDKFindingSeverity = asset.required ? .blocker : .warning
                findings.append(PDKValidationFinding(
                    severity: severity,
                    code: asset.required ? "pdk.validation.required-asset-unavailable" : "pdk.validation.optional-asset-unavailable",
                    message: "PDK asset could not be resolved: \(error)",
                    entity: asset.assetID,
                    suggestedActions: ["restore_pdk_asset", "check_manifest_relative_path"]
                ))
            }
        }

        if request.validateCrossViews {
            validateCrossViews(
                manifest: decoded.manifest,
                resolvedAssets: resolvedAssets,
                findings: &findings
            )
        }

        let hasBlocker = findings.contains { $0.severity == .blocker }
        let hasError = findings.contains { $0.severity == .error }
        let status: XcircuiteEngineExecutionStatus = hasBlocker ? .blocked : hasError ? .failed : .completed
        var assetDigests: [String: String] = [:]
        for resolvedAsset in resolvedAssets {
            assetDigests[resolvedAsset.assetID] = resolvedAsset.computedSHA256
        }
        let scope = decoded.manifest.qualificationScope(
            pdkDigest: request.pdk.digest,
            assetDigests: assetDigests
        )
        let capabilityReport = decoded.manifest.capabilityReport(
            pdkDigest: request.pdk.digest,
            resolvedAssetIDs: Set(resolvedAssets.map(\.assetID))
        )
        return result(
            status: status,
            findings: findings,
            resolvedAssets: resolvedAssets,
            request: request,
            qualificationScope: scope,
            capabilityReport: capabilityReport
        )
    }

    private func validateCrossViews(
        manifest: PDKManifest,
        resolvedAssets: [PDKResolvedAsset],
        findings: inout [PDKValidationFinding]
    ) {
        let resolvedIDs = Set(resolvedAssets.map(\.assetID))
        if manifest.crossViewMappings.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.cross-view-semantics-unavailable",
                message: "No cross-view mappings are available; file presence cannot prove semantic consistency.",
                entity: "crossViewMappings",
                suggestedActions: ["declare_cross_view_mappings", "retain_reference_correlation"]
            ))
            return
        }
        let views = Set(manifest.crossViewMappings.map(\.view))
        let expectedViews: Set<PDKViewKind> = [.layerMap, .spice]
        for view in expectedViews where !views.contains(view) {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.cross-view-required-view-missing",
                message: "Required cross-view semantic mapping is missing.",
                entity: view.rawValue,
                suggestedActions: ["declare_cross_view_mappings"]
            ))
        }
        let layerMappingIDs = Set(
            manifest.crossViewMappings
                .filter { $0.view == .layerMap }
                .flatMap(\.layerIDs)
        )
        for layerID in manifest.layers.map(\.layerID) where !layerMappingIDs.contains(layerID) {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.cross-view-layer-unmapped",
                message: "Layer is not covered by a layer-map cross-view mapping.",
                entity: layerID,
                suggestedActions: ["complete_layer_map_mapping"]
            ))
        }
        let deviceMappingIDs = Set(
            manifest.crossViewMappings
                .filter { $0.view == .spice }
                .flatMap(\.deviceIDs)
        )
        for deviceID in manifest.devices.map(\.deviceID) where !deviceMappingIDs.contains(deviceID) {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.cross-view-device-unmapped",
                message: "Device is not covered by a SPICE cross-view mapping.",
                entity: deviceID,
                suggestedActions: ["complete_spice_mapping"]
            ))
        }
        let cornerMappingIDs = Set(
            manifest.crossViewMappings
                .filter { $0.view == .spice }
                .flatMap(\.cornerIDs)
        )
        for cornerID in manifest.corners.map(\.cornerID) where !cornerMappingIDs.contains(cornerID) {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.cross-view-corner-unmapped",
                message: "Corner is not covered by a SPICE cross-view mapping.",
                entity: cornerID,
                suggestedActions: ["complete_corner_mapping"]
            ))
        }
        let roleToView: [(PDKAssetRole, PDKViewKind)] = [
            (.lef, .lef),
            (.gdsii, .gdsii),
            (.oasis, .oasis),
            (.liberty, .liberty),
        ]
        for (role, view) in roleToView {
            let requiredAssetIDs = Set(manifest.assets.filter { $0.role == role }.map(\.assetID))
            let mappedAssetIDs = Set(manifest.crossViewMappings.filter { $0.view == view }.map(\.assetID))
            for assetID in requiredAssetIDs.subtracting(mappedAssetIDs) {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.validation.cross-view-mapping-missing",
                    message: "Declared view asset has no matching semantic mapping.",
                    entity: assetID,
                    suggestedActions: ["declare_cross_view_mappings"]
                ))
            }
        }
        for mapping in manifest.crossViewMappings where !resolvedIDs.contains(mapping.assetID) {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.validation.cross-view-asset-unavailable",
                message: "Cross-view mapping points at an asset that was not resolved.",
                entity: mapping.mappingID,
                suggestedActions: ["restore_cross_view_asset"]
            ))
        }
    }

    private func validateInputs(
        _ inputs: [XcircuiteFileReference],
        findings: inout [PDKValidationFinding]
    ) {
        for input in inputs {
            let url = URL(filePath: input.path).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.validation.input-missing",
                    message: "Declared input artifact does not exist.",
                    entity: input.path,
                    suggestedActions: ["restore_input_artifact"]
                ))
                continue
            }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                findings.append(PDKValidationFinding(
                    severity: .error,
                    code: "pdk.validation.input-unreadable",
                    message: "Declared input artifact could not be read: \(error.localizedDescription)",
                    entity: input.path,
                    suggestedActions: ["check_file_permissions"]
                ))
                continue
            }
            if input.sha256 == nil {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.validation.input-digest-missing",
                    message: "Immutable input artifacts must carry a SHA-256 digest.",
                    entity: input.path,
                    suggestedActions: ["attach_sha256_digest"]
                ))
            } else if let expected = input.sha256 {
                do {
                    let actual = try digestor.digest(data: data)
                    if expected.lowercased() != actual {
                        findings.append(PDKValidationFinding(
                            severity: .blocker,
                            code: "pdk.validation.input-digest-mismatch",
                            message: "Declared input digest does not match the file bytes.",
                            entity: input.path,
                            suggestedActions: ["rebuild_input_reference", "check_immutable_artifact"]
                        ))
                    }
                } catch {
                    findings.append(PDKValidationFinding(
                        severity: .error,
                        code: "pdk.validation.input-hash-failed",
                        message: "Input artifact could not be hashed: \(error.localizedDescription)",
                        entity: input.path,
                        suggestedActions: ["check_file_permissions"]
                    ))
                }
            }
            if input.byteCount == nil {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.validation.input-byte-count-missing",
                    message: "Immutable input artifacts must carry a byte count.",
                    entity: input.path,
                    suggestedActions: ["attach_byte_count"]
                ))
            } else if let expected = input.byteCount, expected != Int64(data.count) {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.validation.input-byte-count-mismatch",
                    message: "Declared input byte count does not match the file.",
                    entity: input.path,
                    suggestedActions: ["rebuild_input_reference"]
                ))
            }
        }
    }

    private func result(
        status: XcircuiteEngineExecutionStatus,
        findings: [PDKValidationFinding],
        resolvedAssets: [PDKResolvedAsset] = [],
        request: PDKValidationRequest,
        qualificationScope: PDKQualificationScope? = nil,
        capabilityReport: PDKCapabilityReport? = nil
    ) -> ValidationResult {
        let diagnostics = findings.map(PDKValidationDiagnosticMapper.map)
        let missingRequirements = findings
            .filter { $0.severity == .blocker }
            .compactMap(\.entity)
            .sorted()
        return ValidationResult(
            status: status,
            diagnostics: diagnostics,
            findings: findings,
            missingRequirements: missingRequirements,
            resolvedAssets: resolvedAssets,
            qualificationScope: qualificationScope,
            capabilityReport: capabilityReport
        )
    }
}

private struct ValidationResult: Sendable {
    var status: XcircuiteEngineExecutionStatus
    var diagnostics: [XcircuiteEngineDiagnostic]
    var findings: [PDKValidationFinding]
    var missingRequirements: [String]
    var resolvedAssets: [PDKResolvedAsset]
    var qualificationScope: PDKQualificationScope?
    var capabilityReport: PDKCapabilityReport?
}
