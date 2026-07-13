import Foundation
import CircuiteFoundation
import PDKCore
import CircuiteFoundation

public struct LocalPDKManifestViewInspector: PDKManifestViewInspecting {
    private let clock: any PDKStandardViewExecutionClock
    private let assetResolver: any PDKAssetResolving
    private let standardInspector: any PDKStandardViewInspecting
    private let bindingValidator: PDKManifestViewBindingValidator

    public init(
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock(),
        assetResolver: any PDKAssetResolving = LocalPDKAssetResolver(),
        standardInspector: any PDKStandardViewInspecting = LocalPDKStandardViewInspector(),
        bindingValidator: PDKManifestViewBindingValidator = PDKManifestViewBindingValidator()
    ) {
        self.clock = clock
        self.assetResolver = assetResolver
        self.standardInspector = standardInspector
        self.bindingValidator = bindingValidator
    }

    public func execute(
        _ request: PDKManifestViewInspectionRequest
    ) async throws -> PDKManifestViewInspectionResult {
        let startedAt = clock.now()
        let manifestURL: URL
        do {
            manifestURL = try PDKArtifactURLResolver().resolve(
                request.pdk.manifest.locator,
                baseDirectoryPath: request.projectRootPath
            )
        } catch {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.manifest-path-invalid",
                message: "PDK manifest reference could not be resolved: \(error.localizedDescription)",
                entity: request.pdk.manifest.path,
                suggestedActions: ["provide_project_root", "repair_manifest_reference"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding]
            )
        }
        let manifest: PDKManifest
        do {
            let manifestArtifact = try PDKFoundationArtifactBridge.artifactReference(
                for: request.pdk.manifest,
                resolvedURL: manifestURL
            )
            let integrity = LocalArtifactVerifier().verify(manifestArtifact)
            guard integrity.isVerified else {
                let issue = integrity.issues.first
                let code = issue?.code == .digestMismatch
                    ? "pdk.standard-view.manifest-digest-mismatch"
                    : "pdk.standard-view.manifest-integrity-failed"
                let finding = PDKValidationFinding(
                    severity: .blocker,
                    code: code,
                    message: "PDK manifest integrity verification failed: \(issue?.code.rawValue ?? "unknown").",
                    entity: manifestURL.path,
                    suggestedActions: ["rebuild_pdk_reference", "restore_immutable_artifact"]
                )
                return makeEnvelope(
                    request: request,
                    startedAt: startedAt,
                    status: .blocked,
                    findings: [finding]
                )
            }
            let data = try Data(contentsOf: manifestURL)
            manifest = try PDKManifestCodec.decode(data: data).manifest
        } catch let error as PDKManifestError {
            let finding = PDKValidationFinding(
                severity: .error,
                code: "pdk.standard-view.manifest-decode-failed",
                message: "PDK manifest could not be decoded: \(error)",
                entity: manifestURL.path,
                suggestedActions: ["repair_pdk_manifest", "run_pdkkit_inspect"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                findings: [finding]
            )
        } catch {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.manifest-unreadable",
                message: "PDK manifest could not be read or hashed: \(error.localizedDescription)",
                entity: manifestURL.path,
                suggestedActions: ["restore_pdk_manifest", "check_file_permissions"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding]
            )
        }

        guard let asset = manifest.assets.first(where: { $0.assetID == request.assetID }) else {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.asset-missing",
                message: "The requested standard-view asset is not declared by the PDK manifest.",
                entity: request.assetID,
                suggestedActions: ["add_pdk_asset", "repair_pdk_manifest"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding]
            )
        }
        guard asset.format == request.format.fileFormat else {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.manifest-format-mismatch",
                message: "The manifest asset format does not match the requested standard-view parser.",
                entity: request.assetID,
                suggestedActions: ["repair_pdk_manifest", "select_matching_view_parser"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding]
            )
        }

        let resolved: PDKResolvedAsset
        do {
            resolved = try assetResolver.resolve(asset, relativeTo: manifestURL)
        } catch {
            let finding = PDKValidationFinding(
                severity: asset.required ? .blocker : .warning,
                code: "pdk.standard-view.asset-unavailable",
                message: "The standard-view asset could not be resolved: \(error)",
                entity: request.assetID,
                suggestedActions: ["restore_pdk_asset", "check_manifest_relative_path"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: asset.required ? .blocked : .failed,
                findings: [finding]
            )
        }

        let mapping = manifest.crossViewMappings.first {
            $0.assetID == request.assetID && $0.view == request.format.manifestView
        }
        let mappedLayerDefinitions = mapping?.layerIDs.compactMap { layerID in
            manifest.layers.first { $0.layerID == layerID }
        } ?? []
        let expectedLayerNames: [String]
        let expectedPhysicalLayerNumbers: [Int]
        switch request.format {
        case .lef:
            expectedLayerNames = mappedLayerDefinitions.map(\.name)
            expectedPhysicalLayerNumbers = []
        case .gdsii, .oasis:
            expectedLayerNames = []
            expectedPhysicalLayerNumbers = mappedLayerDefinitions.map(\.number)
        case .spice, .liberty:
            expectedLayerNames = []
            expectedPhysicalLayerNumbers = []
        }
        let mappedDeviceIDs: [String] = mapping?.deviceIDs ?? []
        let expectedCellNames: [String] = mappedDeviceIDs.flatMap { deviceID in
            guard let device = manifest.devices.first(where: { $0.deviceID == deviceID }) else {
                return [String]()
            }
                if request.format == .spice {
                    return [device.modelName] + device.aliases
                }
            return [device.deviceID] + device.aliases
        }

        let inspectionRequest = PDKStandardViewInspectionRequest(
            runID: request.runID,
                inputs: [resolved.reference.locator],
            format: request.format,
            assetID: request.assetID,
            requireNonEmpty: request.requireNonEmpty,
            expectedLayerNames: expectedLayerNames,
            expectedPhysicalLayerNumbers: expectedPhysicalLayerNumbers,
            expectedCellNames: expectedCellNames,
            projectRootPath: request.projectRootPath
        )
        let inspectionEnvelope = try await standardInspector.execute(inspectionRequest)
        var findings = inspectionEnvelope.payload.findings
        var binding: PDKStandardViewBindingReport?
        if let inspection = inspectionEnvelope.payload.inspection {
            let report = bindingValidator.validate(
                manifest: manifest,
                assetID: request.assetID,
                format: request.format,
                inspection: inspection
            )
            binding = report
            findings.append(contentsOf: report.findings)
        }

        let bindingIsValid = binding?.isValid ?? false
        let status: PDKExecutionStatus
        switch inspectionEnvelope.status {
        case .failed, .cancelled:
            status = inspectionEnvelope.status
        case .blocked:
            status = .blocked
        case .completed:
            status = bindingIsValid ? .completed : .blocked
        }
        return makeEnvelope(
            request: request,
            startedAt: startedAt,
            status: status,
            findings: findings,
            artifacts: inspectionEnvelope.artifacts,
            inspection: inspectionEnvelope.payload,
            binding: binding
        )
    }

    private func makeEnvelope(
        request: PDKManifestViewInspectionRequest,
        startedAt: Date,
        status: PDKExecutionStatus,
        findings: [PDKValidationFinding],
        artifacts: [ArtifactLocator] = [],
        inspection: PDKStandardViewInspectionPayload? = nil,
        binding: PDKStandardViewBindingReport? = nil
    ) -> PDKManifestViewInspectionResult {
        PDKManifestViewInspectionResult(
            schemaVersion: PDKManifestViewInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: findings.map(PDKStandardViewDiagnosticMapper.map),
            artifacts: artifacts,
            metadata: PDKExecutionMetadata(
                engineID: "PDKManifestViewInspection",
                implementationID: "LocalPDKManifestViewInspector",
                implementationVersion: "1",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: PDKManifestViewInspectionPayload(
                isValid: status == .completed,
                assetID: request.assetID,
                pdkDigest: request.pdk.digest,
                inspection: inspection,
                binding: binding,
                findings: findings,
                limitations: [
                    "Manifest binding verifies declared layer/device/corner coverage against the parsed detailed view.",
                    "Detailed numeric semantic blockers remain fail-closed for unsupported SPICE expressions and incomplete Liberty timing tables.",
                    "This result is not a foundry qualification or reference-oracle decision."
                ]
            )
        )
    }
}
