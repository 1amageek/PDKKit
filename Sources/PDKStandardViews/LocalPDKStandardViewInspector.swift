import Foundation
import GDSII
import LEF
import LayoutIR
import OASIS
import PDKCore
import XcircuitePackage

public struct LocalPDKStandardViewInspector: PDKStandardViewInspecting {
    private let clock: any PDKStandardViewExecutionClock

    public init(
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock()
    ) {
        self.clock = clock
    }

    public func execute(
        _ request: PDKStandardViewInspectionRequest
    ) async throws -> XcircuiteEngineResultEnvelope<PDKStandardViewInspectionPayload> {
        let startedAt = clock.now()
        guard request.inputs.count == 1, let input = request.inputs.first else {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.input-count-invalid",
                message: "Exactly one standard-view input artifact is required.",
                entity: request.assetID,
                suggestedActions: ["provide_one_standard_view_artifact"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding]
            )
        }

        guard input.format == request.format.fileFormat else {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.format-mismatch",
                message: "The input artifact format does not match the requested standard-view parser.",
                entity: request.assetID,
                suggestedActions: ["correct_standard_view_format", "rebuild_input_reference"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding],
                artifacts: [input]
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: URL(filePath: input.path))
        } catch {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.input-unreadable",
                message: "The standard-view artifact could not be read: \(error.localizedDescription)",
                entity: input.path,
                suggestedActions: ["restore_standard_view_artifact", "check_file_permissions"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding],
                artifacts: [input]
            )
        }

        var findings = verifyIntegrity(data: data, reference: input)
        guard !findings.contains(where: { $0.severity == .blocker || $0.severity == .error }) else {
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: findings,
                artifacts: [input]
            )
        }

        do {
            let inspection = try parse(data: data, reference: input, format: request.format)
            findings.append(contentsOf: semanticFindings(inspection: inspection, request: request))
            let hasBlocker = findings.contains { $0.severity == .blocker }
            let status: XcircuiteEngineExecutionStatus = hasBlocker ? .blocked : .completed
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: status,
                findings: findings,
                artifacts: [input],
                inspection: inspection
            )
        } catch {
            let finding = PDKValidationFinding(
                severity: .error,
                code: "pdk.standard-view.parse-failed",
                message: "The standard-view parser rejected the artifact: \(error)",
                entity: input.path,
                suggestedActions: ["repair_standard_view_artifact", "run_format_specific_parser"]
            )
            findings.append(finding)
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                findings: findings,
                artifacts: [input]
            )
        }
    }

    private func verifyIntegrity(
        data: Data,
        reference: XcircuiteFileReference
    ) -> [PDKValidationFinding] {
        var findings: [PDKValidationFinding] = []
        guard let expectedDigest = reference.sha256, !expectedDigest.isEmpty else {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.digest-missing",
                message: "Standard-view input must carry a SHA-256 digest.",
                entity: reference.path,
                suggestedActions: ["rebuild_input_reference"]
            ))
            return findings
        }
        guard let expectedByteCount = reference.byteCount else {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.byte-count-missing",
                message: "Standard-view input must carry a byte count.",
                entity: reference.path,
                suggestedActions: ["rebuild_input_reference"]
            ))
            return findings
        }

        do {
            let actualDigest = try SHA256PDKDigestor().digest(data: data)
            if actualDigest != expectedDigest.lowercased() {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.digest-mismatch",
                    message: "Standard-view input bytes do not match the recorded SHA-256 digest.",
                    entity: reference.path,
                    suggestedActions: ["rebuild_input_reference", "restore_immutable_artifact"]
                ))
            }
        } catch {
            findings.append(PDKValidationFinding(
                severity: .error,
                code: "pdk.standard-view.digest-failed",
                message: "Standard-view input could not be hashed: \(error.localizedDescription)",
                entity: reference.path,
                suggestedActions: ["check_file_permissions"]
            ))
        }
        if Int64(data.count) != expectedByteCount {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.byte-count-mismatch",
                message: "Standard-view input bytes do not match the recorded byte count.",
                entity: reference.path,
                suggestedActions: ["rebuild_input_reference", "restore_immutable_artifact"]
            ))
        }
        return findings
    }

    private func parse(
        data: Data,
        reference: XcircuiteFileReference,
        format: PDKStandardViewFormat
    ) throws -> PDKStandardViewIR {
        switch format {
        case .lef:
            let document = try LEFLibraryReader.read(data)
            return PDKStandardViewIR(
                format: .lef,
                source: reference,
                libraryName: "LEF",
                layerNames: document.layers.map(\.name),
                cellNames: document.macros.map(\.name),
                viaNames: document.vias.map(\.name),
                elementCount: document.layers.count + document.macros.count + document.vias.count,
                metadata: [
                    "lef.version": document.version,
                    "dbuPerMicron": String(document.dbuPerMicron)
                ]
            )
        case .gdsii:
            let library = try GDSLibraryReader.read(data)
            return makeMaskIR(library: library, reference: reference, format: .gdsii)
        case .oasis:
            let library = try OASISLibraryReader.read(data)
            return makeMaskIR(library: library, reference: reference, format: .oasis)
        case .spice:
            return try parseSPICE(data: data, reference: reference)
        case .liberty:
            return try parseLiberty(data: data, reference: reference)
        }
    }

    private func parseSPICE(
        data: Data,
        reference: XcircuiteFileReference
    ) throws -> PDKStandardViewIR {
        guard let text = String(data: data, encoding: .utf8) else {
            throw PDKStandardViewTextParseError.invalidEncoding
        }
        let lines = logicalTextLines(text)
        var modelNames: [String] = []
        var modelTypes: [String] = []
        var modelParameterNames: [String] = []
        var subcircuitNames: [String] = []
        var terminalNames: [String] = []
        var cornerNames: [String] = []
        var openSubcircuits: [String] = []
        var openLibrarySections: [String] = []
        var sawEnd = false

        for (lineNumber, line) in lines {
            let tokens = line.split { $0 == " " || $0 == "\t" }.map(String.init)
            guard let first = tokens.first else { continue }
            switch first.lowercased() {
            case ".model":
                guard tokens.count >= 3 else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".model requires a model name and model type"
                    )
                }
                modelNames.append(tokens[1])
                modelTypes.append(tokens[2])
                modelParameterNames.append(contentsOf: parameterNames(in: tokens.dropFirst(3)))
            case ".subckt":
                guard tokens.count >= 3 else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".subckt requires a name and at least one terminal"
                    )
                }
                subcircuitNames.append(tokens[1])
                terminalNames.append(contentsOf: tokens.dropFirst(2))
                openSubcircuits.append(tokens[1])
            case ".ends":
                guard let openName = openSubcircuits.popLast() else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".ends has no matching .subckt"
                    )
                }
                if tokens.count > 1, tokens[1].caseInsensitiveCompare(openName) != .orderedSame {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".ends name does not match the open subcircuit"
                    )
                }
            case ".lib":
                if tokens.count > 1 {
                    let sectionName = tokens.count > 2 ? tokens[tokens.count - 1] : tokens[1]
                    cornerNames.append(sectionName.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))
                    openLibrarySections.append(sectionName)
                }
            case ".endl":
                guard let openName = openLibrarySections.popLast() else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".endl has no matching .lib section"
                    )
                }
                if tokens.count > 1, tokens[1].caseInsensitiveCompare(openName) != .orderedSame {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".endl name does not match the open .lib section"
                    )
                }
            case ".param":
                modelParameterNames.append(contentsOf: parameterNames(in: tokens.dropFirst()))
            case ".func":
                if tokens.count > 1 {
                    modelParameterNames.append(tokens[1].split(separator: "(", maxSplits: 1).first.map(String.init) ?? tokens[1])
                }
            case ".end":
                sawEnd = true
            default:
                continue
            }
        }

        if let openName = openSubcircuits.last {
            throw PDKStandardViewTextParseError.malformed(
                format: .spice,
                line: lines.last?.0 ?? 0,
                reason: "subcircuit \(openName) is not closed"
            )
        }
        if let openName = openLibrarySections.last {
            throw PDKStandardViewTextParseError.malformed(
                format: .spice,
                line: lines.last?.0 ?? 0,
                reason: "library section \(openName) is not closed"
            )
        }
        return PDKStandardViewIR(
            format: .spice,
            source: reference,
            libraryName: "SPICE",
            cellNames: subcircuitNames,
            modelNames: modelNames,
            modelTypes: modelTypes,
            modelParameterNames: modelParameterNames,
            pinNames: terminalNames,
            cornerNames: cornerNames,
            elementCount: lines.count,
            metadata: [
                "spice.modelCount": String(modelNames.count),
                "spice.modelTypeCount": String(modelTypes.count),
                "spice.modelParameterCount": String(modelParameterNames.count),
                "spice.subcircuitCount": String(subcircuitNames.count),
                "spice.endSeen": String(sawEnd)
            ]
        )
    }

    private func parseLiberty(
        data: Data,
        reference: XcircuiteFileReference
    ) throws -> PDKStandardViewIR {
        guard let text = String(data: data, encoding: .utf8) else {
            throw PDKStandardViewTextParseError.invalidEncoding
        }
        let lines = libertyLines(text)
        var libraryName = ""
        var cellNames: [String] = []
        var pinNames: [String] = []
        var timingArcCount = 0
        var timingRelatedPinNames: [String] = []
        var timingTableValueCount = 0
        var braceDepth = 0

        for (lineNumber, line) in lines {
            braceDepth += line.filter { $0 == "{" }.count
            braceDepth -= line.filter { $0 == "}" }.count
            if braceDepth < 0 {
                throw PDKStandardViewTextParseError.malformed(
                    format: .liberty,
                    line: lineNumber,
                    reason: "closing brace has no matching opening brace"
                )
            }
            if isDeclaration(line, keyword: "library") {
                libraryName = try declarationName(
                    line,
                    keyword: "library",
                    format: .liberty,
                    lineNumber: lineNumber
                )
            } else if isDeclaration(line, keyword: "cell") {
                cellNames.append(try declarationName(
                    line,
                    keyword: "cell",
                    format: .liberty,
                    lineNumber: lineNumber
                ))
            } else if isDeclaration(line, keyword: "pin") {
                pinNames.append(try declarationName(
                    line,
                    keyword: "pin",
                    format: .liberty,
                    lineNumber: lineNumber
                ))
            } else if isDeclaration(line, keyword: "timing") {
                timingArcCount += 1
            } else if let relatedPin = attributeValue(line, name: "related_pin") {
                timingRelatedPinNames.append(relatedPin)
            } else if isValuesDeclaration(line) {
                timingTableValueCount += valuesCount(in: line)
            }
        }

        guard !libraryName.isEmpty else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: lines.first?.0 ?? 0,
                reason: "library declaration is missing"
            )
        }
        guard !cellNames.isEmpty else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: lines.first?.0 ?? 0,
                reason: "at least one cell declaration is required"
            )
        }
        guard braceDepth == 0 else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: lines.last?.0 ?? 0,
                reason: "liberty braces are unbalanced"
            )
        }
        return PDKStandardViewIR(
            format: .liberty,
            source: reference,
            libraryName: libraryName,
            cellNames: cellNames,
            pinNames: pinNames,
            cornerNames: [libraryName],
            timingArcCount: timingArcCount,
            timingRelatedPinNames: timingRelatedPinNames,
            timingTableValueCount: timingTableValueCount,
            elementCount: lines.count,
            metadata: [
                "liberty.cellCount": String(cellNames.count),
                "liberty.pinCount": String(pinNames.count),
                "liberty.timingArcCount": String(timingArcCount),
                "liberty.timingRelatedPinCount": String(timingRelatedPinNames.count),
                "liberty.timingTableValueCount": String(timingTableValueCount)
            ]
        )
    }

    private func parameterNames<S: Sequence>(in tokens: S) -> [String] where S.Element == String {
        tokens.compactMap { token in
            guard let separator = token.firstIndex(of: "=") else { return nil }
            let name = String(token[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
    }

    private func logicalTextLines(_ text: String) -> [(Int, String)] {
        var result: [(Int, String)] = []
        var currentLineNumber: Int?
        var currentValue = ""
        for (offset, rawLine) in text.split(whereSeparator: { $0.isNewline }).enumerated() {
            let lineNumber = offset + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("*") {
                continue
            }
            if trimmed.hasPrefix("+") {
                currentValue += " " + trimmed.dropFirst()
            } else {
                if let currentLineNumber {
                    result.append((currentLineNumber, currentValue))
                }
                currentLineNumber = lineNumber
                currentValue = trimmed
            }
        }
        if let currentLineNumber {
            result.append((currentLineNumber, currentValue))
        }
        return result
    }

    private func libertyLines(_ text: String) -> [(Int, String)] {
        var result: [(Int, String)] = []
        var inBlockComment = false
        for (offset, rawLine) in text.split(whereSeparator: { $0.isNewline }).enumerated() {
            let lineNumber = offset + 1
            var line = String(rawLine)
            if inBlockComment {
                guard let end = line.range(of: "*/") else { continue }
                line = String(line[end.upperBound...])
                inBlockComment = false
            }
            while let start = line.range(of: "/*") {
                guard let end = line.range(of: "*/", range: start.upperBound..<line.endIndex) else {
                    line = String(line[..<start.lowerBound])
                    inBlockComment = true
                    break
                }
                line.removeSubrange(start.lowerBound..<end.upperBound)
            }
            if let comment = line.range(of: "//") {
                line = String(line[..<comment.lowerBound])
            }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append((lineNumber, trimmed))
            }
        }
        return result
    }

    private func declarationName(
        _ line: String,
        keyword: String,
        format: PDKStandardViewFormat,
        lineNumber: Int
    ) throws -> String {
        guard let opening = line.firstIndex(of: "("),
              let closing = line[opening...].firstIndex(of: ")"),
              opening < closing else {
            throw PDKStandardViewTextParseError.malformed(
                format: format,
                line: lineNumber,
                reason: "\(keyword) declaration is missing a parenthesized name"
            )
        }
        let name = line[line.index(after: opening)..<closing]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard !name.isEmpty else {
            throw PDKStandardViewTextParseError.malformed(
                format: format,
                line: lineNumber,
                reason: "\(keyword) declaration has an empty name"
            )
        }
        return name
    }

    private func attributeValue(_ line: String, name: String) -> String? {
        let lowercased = line.lowercased()
        guard lowercased.hasPrefix(name),
              let colon = line.firstIndex(of: ":") else {
            return nil
        }
        let rawValue = line[line.index(after: colon)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if rawValue.first == "\"", let closing = rawValue.dropFirst().firstIndex(of: "\"") {
            return String(rawValue[rawValue.index(after: rawValue.startIndex)..<closing])
        }
        return rawValue.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
    }

    private func isValuesDeclaration(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return (lowercased.hasPrefix("values") && lowercased.dropFirst("values".count).first == " ") ||
            lowercased.hasPrefix("values(")
    }

    private func valuesCount(in line: String) -> Int {
        guard let opening = line.firstIndex(of: "("),
              let closing = line[opening...].lastIndex(of: ")"),
              opening < closing else {
            return 0
        }
        let values = line[line.index(after: opening)..<closing]
            .split { $0.isWhitespace || $0 == "," }
        return values.filter {
            let value = String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return Double(value) != nil
        }.count
    }

    private func isDeclaration(_ line: String, keyword: String) -> Bool {
        let lowercased = line.lowercased()
        guard lowercased.hasPrefix(keyword) else {
            return false
        }
        guard lowercased.count > keyword.count else {
            return true
        }
        let boundary = lowercased.index(lowercased.startIndex, offsetBy: keyword.count)
        return lowercased[boundary] == "(" || lowercased[boundary].isWhitespace
    }

    private func makeMaskIR(
        library: IRLibrary,
        reference: XcircuiteFileReference,
        format: PDKStandardViewFormat
    ) -> PDKStandardViewIR {
        let elements = library.cells.flatMap(\.elements)
        let layerNumbers = elements.flatMap(layerNumbers(for:))
        return PDKStandardViewIR(
            format: format,
            source: reference,
            libraryName: library.name,
            physicalLayerNumbers: layerNumbers,
            cellNames: library.cells.map(\.name),
            elementCount: elements.count,
            metadata: ["dbuPerMicron": String(library.units.dbuPerMicron)]
        )
    }

    private func layerNumbers(for element: IRElement) -> [Int] {
        switch element {
        case .boundary(let boundary): [Int(boundary.layer)]
        case .path(let path): [Int(path.layer)]
        case .text(let text): [Int(text.layer)]
        case .cellRef, .arrayRef: []
        }
    }

    private func semanticFindings(
        inspection: PDKStandardViewIR,
        request: PDKStandardViewInspectionRequest
    ) -> [PDKValidationFinding] {
        var findings: [PDKValidationFinding] = []
        if request.requireNonEmpty {
            let hasSemanticContent: Bool
            switch request.format {
            case .lef:
                hasSemanticContent = !inspection.layerNames.isEmpty || !inspection.cellNames.isEmpty || !inspection.viaNames.isEmpty
            case .gdsii, .oasis:
                hasSemanticContent = !inspection.cellNames.isEmpty && inspection.elementCount > 0
            case .spice:
                hasSemanticContent = !inspection.modelNames.isEmpty || !inspection.cellNames.isEmpty
            case .liberty:
                hasSemanticContent = !inspection.cellNames.isEmpty && !inspection.cornerNames.isEmpty
            }
            if !hasSemanticContent {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.semantic-content-missing",
                    message: "The parsed standard-view artifact contains no usable semantic records.",
                    entity: request.assetID,
                    suggestedActions: ["restore_standard_view_artifact", "check_cross_view_mapping"]
                ))
            }
        }

        let missingLayerNames = missingNames(request.expectedLayerNames, observed: inspection.layerNames)
        if !missingLayerNames.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.layer-binding-missing",
                message: "Expected standard-view layer names are absent: \(missingLayerNames.joined(separator: ", ")).",
                entity: request.assetID,
                suggestedActions: ["repair_cross_view_mapping", "inspect_standard_view_layers"]
            ))
        }
        let missingPhysicalLayers = request.expectedPhysicalLayerNumbers.filter {
            !inspection.physicalLayerNumbers.contains($0)
        }
        if !missingPhysicalLayers.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.physical-layer-binding-missing",
                message: "Expected physical layer numbers are absent: \(missingPhysicalLayers.map(String.init).joined(separator: ", ")).",
                entity: request.assetID,
                suggestedActions: ["repair_layer_map", "inspect_mask_layers"]
            ))
        }
        let observedCellNames = request.format == .spice
            ? inspection.cellNames + inspection.modelNames
            : inspection.cellNames
        let missingCellNames = missingNames(request.expectedCellNames, observed: observedCellNames)
        if !missingCellNames.isEmpty {
            findings.append(PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.cell-binding-missing",
                message: "Expected standard-view cell names are absent: \(missingCellNames.joined(separator: ", ")).",
                entity: request.assetID,
                suggestedActions: ["repair_cross_view_mapping", "inspect_standard_view_cells"]
            ))
        }
        return findings
    }

    private func missingNames(_ expected: [String], observed: [String]) -> [String] {
        expected.filter { value in
            !observed.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
        }
    }

    private func makeEnvelope(
        request: PDKStandardViewInspectionRequest,
        startedAt: Date,
        status: XcircuiteEngineExecutionStatus,
        findings: [PDKValidationFinding],
        artifacts: [XcircuiteFileReference] = [],
        inspection: PDKStandardViewIR? = nil
    ) -> XcircuiteEngineResultEnvelope<PDKStandardViewInspectionPayload> {
        XcircuiteEngineResultEnvelope(
            schemaVersion: PDKStandardViewInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: findings.map(PDKStandardViewDiagnosticMapper.map),
            artifacts: artifacts,
            metadata: XcircuiteEngineExecutionMetadata(
                engineID: "PDKStandardViewInspection",
                implementationID: "LocalPDKStandardViewInspector",
                implementationVersion: "1",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: PDKStandardViewInspectionPayload(
                isValid: status == .completed,
                assetID: request.assetID,
                inspection: inspection,
                findings: findings,
                parserID: "swift-mask-data",
                parserVersion: "workspace",
                limitations: [
                    "This inspection proves parsed structural semantics for the selected standard view.",
                    "It does not establish foundry qualification or oracle correlation."
                ]
            )
        )
    }
}
