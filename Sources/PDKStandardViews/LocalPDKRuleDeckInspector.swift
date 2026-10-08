import Foundation
import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFoundation
import PDKCore
import PDKSourceCapture

public struct LocalPDKRuleDeckInspector: PDKRuleDeckInspecting {
    private let clock: any PDKStandardViewExecutionClock
    private let assetResolver: any PDKAssetResolving
    private let sourceCapturer: any PDKLocalSourceCapturing
    private let captureBudget: ArtifactAccessBudget?

    public init(
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock(),
        assetResolver: any PDKAssetResolving = LocalPDKAssetResolver(),
        digester: any ContentDigesting = SHA256ContentDigester(),
        sourceCapturer: (any PDKLocalSourceCapturing)? = nil,
        captureBudget: ArtifactAccessBudget? = nil
    ) {
        self.clock = clock
        self.assetResolver = assetResolver
        self.sourceCapturer = sourceCapturer ?? LocalPDKSourceCapturer(digester: digester)
        self.captureBudget = captureBudget
    }

    public func execute(
        _ request: PDKRuleDeckInspectionRequest
    ) async throws -> PDKRuleDeckInspectionResult {
        let startedAt = clock.now()
        guard request.schemaVersion == PDKRuleDeckInspectionRequest.currentSchemaVersion else {
            return try makeResult(request: request, startedAt: startedAt, status: .blocked,
                findings: [PDKValidationFinding(severity: .blocker, code: "pdk.rule-deck.request-schema-unsupported",
                    message: "Unsupported request schema version.", entity: "schemaVersion", suggestedActions: ["migrate_request_schema"])])
        }
        let manifestURL: URL
        do {
            manifestURL = try PDKArtifactURLResolver().resolve(
                request.pdk.manifestLocator,
                baseDirectoryPath: request.projectRootPath
            )
        } catch {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding(
                    severity: .blocker,
                    code: "pdk.rule-deck.manifest-path-invalid",
                    message: "PDK manifest reference could not be resolved: " + error.localizedDescription,
                    entity: request.pdk.manifestLocator.path,
                    actions: ["provide_project_root", "repair_manifest_reference"]
                )]
            )
        }

        let manifest: PDKManifest
        do {
            let budget = try captureBudget ?? PDKSourceCapturePolicy.defaultBudget
            let captured = try await sourceCapturer.capture(
                reference: request.pdk.manifest,
                at: request.pdk.manifestLocator,
                relativeTo: request.pdk.manifestLocator.location.storage == .workspaceRelative
                    ? URL(filePath: request.projectRootPath ?? FileManager.default.currentDirectoryPath) : nil,
                budget: budget
            )
            let data = try captured.data(maximumByteCount: budget.maximumTotalByteCount)
            manifest = try PDKManifestCodec.decode(data: data)
        } catch let error as PDKSourceCaptureError {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: error.classification == .cancellation ? .cancelled : .blocked,
                findings: [finding(
                    severity: .blocker,
                    code: error.classification == .digestMismatch || error.classification == .byteCountMismatch
                        ? "pdk.rule-deck.manifest-integrity-failed" : "pdk.rule-deck.manifest-capture-failed",
                    message: "PDK manifest capture failed: \(error).",
                    entity: manifestURL.path,
                    actions: ["restore_immutable_artifact", "inspect_capture_failure"]
                )]
            )
        } catch let error as PDKManifestError {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: .failed,
                findings: [finding(
                    severity: .error,
                    code: "pdk.rule-deck.manifest-decode-failed",
                    message: "PDK manifest could not be decoded: " + String(describing: error),
                    entity: manifestURL.path,
                    actions: ["repair_pdk_manifest", "run_pdkkit_inspect"]
                )]
            )
        } catch {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding(
                    severity: .blocker,
                    code: "pdk.rule-deck.manifest-unreadable",
                    message: "PDK manifest could not be read or hashed: " + error.localizedDescription,
                    entity: manifestURL.path,
                    actions: ["restore_pdk_manifest", "check_file_permissions"]
                )]
            )
        }

        guard let asset = manifest.assets.first(where: { $0.assetID == request.assetID }) else {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding(
                    severity: .blocker,
                    code: "pdk.rule-deck.asset-missing",
                    message: "The requested rule-deck asset is not declared by the PDK manifest.",
                    entity: request.assetID,
                    actions: ["add_rule_deck_asset", "repair_pdk_manifest"]
                )]
            )
        }
        guard asset.role == .ruleDeck else {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding(
                    severity: .blocker,
                    code: "pdk.rule-deck.asset-role-mismatch",
                    message: "The requested asset is not declared with the ruleDeck role.",
                    entity: request.assetID,
                    actions: ["repair_pdk_manifest", "select_rule_deck_asset"]
                )]
            )
        }

        guard let mapping = manifest.crossViewMappings.first(where: {
            $0.assetID == request.assetID && $0.view == .ruleDeck
        }) else {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding(
                    severity: .blocker,
                    code: "pdk.validation.rule-deck-mapping-missing",
                    message: "The declared rule-deck asset has no rule-deck layer mapping.",
                    entity: request.assetID,
                    actions: ["add_rule_deck_mapping", "declare_rule_deck_layers"]
                )]
            )
        }

        let resolved: PDKResolvedAsset
        do {
            resolved = try assetResolver.resolve(asset, relativeTo: manifestURL)
        } catch {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: asset.required ? .blocked : .failed,
                reference: nil,
                findings: [finding(
                    severity: asset.required ? .blocker : .warning,
                    code: "pdk.validation.rule-deck-asset-unavailable",
                    message: "The rule-deck asset could not be resolved: " + String(describing: error),
                    entity: request.assetID,
                    actions: ["restore_pdk_asset", "check_manifest_relative_path"]
                )]
            )
        }

        var identityFindings = asset.identityFindings(for: resolved.reference).map { finding in
            var finding = finding
            finding.code = finding.code.replacingOccurrences(of: "asset-", with: "rule-deck-asset-")
            return finding
        }
        if let expected = request.expectedSourceArtifact, expected != resolved.reference {
            identityFindings.append(finding(
                severity: .blocker, code: "pdk.validation.rule-deck-source-artifact-mismatch",
                message: "The resolved rule deck differs from the upstream expected source identity.",
                entity: request.assetID, actions: ["restore_immutable_artifact", "rerun_pdk_validation"]
            ))
        }
        if !identityFindings.isEmpty {
            return try makeResult(request: request, startedAt: startedAt, status: .blocked, findings: identityFindings)
        }

        let sourceArtifact = resolved.reference
        let data: Data
        do {
            let budget = try captureBudget ?? PDKSourceCapturePolicy.defaultBudget
            let captured = try await sourceCapturer.capture(
                reference: resolved.reference,
                at: resolved.locator,
                relativeTo: resolved.locator.location.storage == .workspaceRelative
                    ? manifestURL.deletingLastPathComponent() : nil,
                budget: budget
            )
            data = try captured.data(maximumByteCount: budget.maximumTotalByteCount)
        } catch let error as PDKSourceCaptureError {
            let code: String
            switch error.classification {
            case .digestMismatch:
                code = "pdk.validation.rule-deck-asset-digest-mismatch"
            case .byteCountMismatch:
                code = "pdk.validation.rule-deck-asset-size-mismatch"
            case .cancellation, .cleanup, .other:
                code = "pdk.validation.rule-deck-capture-failed"
            }
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: error.classification == .cancellation ? .cancelled : .blocked,
                reference: resolved.reference,
                referenceLocator: resolved.locator,
                findings: [finding(
                    severity: .blocker,
                    code: code,
                    message: "The rule-deck source could not be captured: \(error).",
                    entity: request.assetID,
                    actions: ["restore_immutable_artifact", "inspect_capture_failure"]
                )]
            )
        } catch {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                reference: resolved.reference,
                referenceLocator: resolved.locator,
                findings: [finding(
                    severity: .blocker,
                    code: "pdk.validation.rule-deck-capture-failed",
                    message: "The rule-deck capture budget is invalid: \(error).",
                    entity: request.assetID,
                    actions: ["repair_capture_budget"]
                )]
            )
        }
        guard let text = String(data: data, encoding: .utf8) else {
            return try makeResult(
                request: request,
                startedAt: startedAt,
                status: .failed,
                reference: resolved.reference,
                referenceLocator: resolved.locator,
                sourceArtifact: sourceArtifact,
                findings: [finding(
                    severity: .error,
                    code: "pdk.validation.rule-deck-invalid-encoding",
                    message: "The rule-deck asset is not valid UTF-8 text.",
                    entity: request.assetID,
                    actions: ["repair_rule_deck_encoding", "use_utf8_rule_deck"]
                )]
            )
        }

        let expectedLayerDefinitions = mapping.layerIDs.compactMap { layerID in
            manifest.layers.first { $0.layerID == layerID }
        }
        var findings: [PDKValidationFinding] = []
        let unknownLayerIDs = mapping.layerIDs.filter { layerID in
            !expectedLayerDefinitions.contains { $0.layerID == layerID }
        }
        if !unknownLayerIDs.isEmpty {
            findings.append(finding(
                severity: .blocker,
                code: "pdk.validation.rule-deck-mapping-layer-missing",
                message: "Rule-deck mapping references unknown layer IDs: " + unknownLayerIDs.joined(separator: ", "),
                entity: request.assetID,
                actions: ["repair_rule_deck_mapping", "declare_manifest_layers"]
            ))
        }

        let parsed = executableStatements(in: text)
        let statements = parsed.statements
        if parsed.hasUnterminatedBlockComment {
            findings.append(finding(
                severity: .error,
                code: "pdk.validation.rule-deck-comment-unclosed",
                message: "Rule-deck text contains an unterminated block comment.",
                entity: request.assetID,
                actions: ["repair_rule_deck_comments", "restore_rule_deck"]
            ))
        }
        if request.requireNonEmpty && statements.isEmpty {
            findings.append(finding(
                severity: .blocker,
                code: "pdk.validation.rule-deck-empty",
                message: "Rule-deck asset contains no executable text statements.",
                entity: request.assetID,
                actions: ["restore_rule_deck", "populate_rule_deck_statements"]
            ))
        }

        let evidence = expectedLayerDefinitions.map { layer in
            layerEvidence(for: layer, statements: statements)
        }
        let observedLayerIDs = evidence.filter { !$0.matchedTokens.isEmpty }.map(\.layerID).sorted()
        let missingLayerIDs = mapping.layerIDs.filter { !observedLayerIDs.contains($0) }
        if !missingLayerIDs.isEmpty {
            findings.append(finding(
                severity: .blocker,
                code: "pdk.validation.rule-deck-layer-missing",
                message: "Rule-deck text does not identify mapped layers: " + missingLayerIDs.joined(separator: ", "),
                entity: request.assetID,
                actions: ["declare_rule_deck_layers", "repair_rule_deck_mapping"]
            ))
        }

        let hasBlocker = findings.contains { $0.severity == .blocker }
        let hasError = findings.contains { $0.severity == .error }
        let status: PDKExecutionStatus = hasBlocker ? .blocked : hasError ? .failed : .completed
        return try makeResult(
            request: request,
            startedAt: startedAt,
            status: status,
            reference: resolved.reference,
            referenceLocator: resolved.locator,
            sourceArtifact: sourceArtifact,
            statementCount: statements.count,
            expectedLayerIDs: mapping.layerIDs.sorted(),
            observedLayerIDs: observedLayerIDs,
            layerEvidence: evidence,
            findings: findings
        )
    }

    private func executableStatements(in text: String) -> (
        statements: [[String]],
        hasUnterminatedBlockComment: Bool
    ) {
        var inBlockComment = false
        let statements: [[String]] = text.split(whereSeparator: \.isNewline).compactMap { rawLine -> [String]? in
            let line = stripComments(from: String(rawLine), inBlockComment: &inBlockComment)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let tokens = tokenize(trimmed)
            guard !tokens.isEmpty else { return nil }
            return tokens
        }
        return (statements, inBlockComment)
    }

    private func stripComments(from line: String, inBlockComment: inout Bool) -> String {
        var output = ""
        var index = line.startIndex
        while index < line.endIndex {
            if inBlockComment {
                if line[index...].hasPrefix("*/") {
                    inBlockComment = false
                    index = line.index(index, offsetBy: 2)
                } else {
                    index = line.index(after: index)
                }
                continue
            }
            if line[index...].hasPrefix("/*") {
                inBlockComment = true
                index = line.index(index, offsetBy: 2)
                continue
            }
            let remaining = line[index...]
            let isLineComment = remaining.hasPrefix("//") || remaining.hasPrefix("#")
            if isLineComment {
                break
            }
            output.append(line[index])
            index = line.index(after: index)
        }
        let trimmed = output.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("*") || trimmed.hasPrefix(";") {
            return ""
        }
        return output
    }

    private func tokenize(_ statement: String) -> [String] {
        statement.split { character in
            character.isWhitespace || [",", ":", "(", ")", "=", ";", "{", "}"].contains(character)
        }.map(String.init)
    }

    private func layerEvidence(
        for layer: PDKLayerDefinition,
        statements: [[String]]
    ) -> PDKRuleDeckLayerEvidence {
        let nameCandidates = [layer.name] + layer.aliases
        let normalizedNames = Set(nameCandidates.map { $0.lowercased() })
        var matchedTokens: Set<String> = []
        var statementIndices: [Int] = []
        for (index, tokens) in statements.enumerated() {
            let normalizedTokens = tokens.map { $0.lowercased() }
            let namesMatch = tokens.filter { normalizedNames.contains($0.lowercased()) }
            let isLayerDeclaration = normalizedTokens.contains {
                ["layer", "layerdef", "layermap", "layer_map", "layer_id"].contains($0)
            }
            let numberMatch = isLayerDeclaration && tokens.contains(String(layer.number))
            if !namesMatch.isEmpty || numberMatch {
                matchedTokens.formUnion(namesMatch)
                if numberMatch {
                    matchedTokens.insert(String(layer.number))
                }
                statementIndices.append(index)
            }
        }
        return PDKRuleDeckLayerEvidence(
            layerID: layer.layerID,
            matchedTokens: matchedTokens.sorted(),
            statementIndices: statementIndices
        )
    }

    private func finding(
        severity: PDKFindingSeverity,
        code: String,
        message: String,
        entity: String,
        actions: [String]
    ) -> PDKValidationFinding {
        PDKValidationFinding(
            severity: severity,
            code: code,
            message: message,
            entity: entity,
            suggestedActions: actions
        )
    }

    private func makeResult(
        request: PDKRuleDeckInspectionRequest,
        startedAt: Date,
        status: PDKExecutionStatus,
        reference: ArtifactReference? = nil,
        referenceLocator: ArtifactLocator? = nil,
        sourceArtifact: ArtifactReference? = nil,
        statementCount: Int = 0,
        expectedLayerIDs: [String] = [],
        observedLayerIDs: [String] = [],
        layerEvidence: [PDKRuleDeckLayerEvidence] = [],
        findings: [PDKValidationFinding]
    ) throws -> PDKRuleDeckInspectionResult {
        try PDKRuleDeckInspectionResult(
            schemaVersion: PDKRuleDeckInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: findings.map(PDKStandardViewDiagnosticMapper.map),
            artifacts: reference.map { [$0] } ?? [],
            provenance: try PDKExecutionProvenance.make(
                engineID: "PDKRuleDeckInspection",
                implementationID: "LocalPDKRuleDeckInspector",
                implementationVersion: "1",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: PDKRuleDeckInspectionPayload(
                isValid: status == .completed,
                assetID: request.assetID,
                pdkDigest: request.pdk.digest,
                reference: referenceLocator,
                sourceArtifact: sourceArtifact,
                statementCount: statementCount,
                expectedLayerIDs: expectedLayerIDs,
                observedLayerIDs: observedLayerIDs,
                layerEvidence: layerEvidence,
                findings: findings,
                limitations: [
                    "The adapter verifies text integrity, executable statements and manifest-mapped layer evidence.",
                    "Vendor-specific rule-deck grammar and geometric rule semantics require a qualified external or native backend.",
                    "This result is not a DRC, LVS, PEX or foundry qualification decision."
                ]
            )
        )
    }
}
