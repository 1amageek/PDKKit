import Foundation
import CircuiteFoundation
import GDSII
import LEF
import LayoutIR
import OASIS
import PDKCore
import CircuiteFoundation

public struct LocalPDKStandardViewInspector: PDKStandardViewInspecting {
    private let clock: any PDKStandardViewExecutionClock

    private struct LibertyToken {
        var value: String
        var line: Int
    }

    private struct LibertyNode {
        var name: String
        var arguments: [String]
        var attributes: [String: [String]]
        var children: [LibertyNode]
    }

    public init(
        clock: any PDKStandardViewExecutionClock = SystemPDKStandardViewExecutionClock()
    ) {
        self.clock = clock
    }

    public func execute(
        _ request: PDKStandardViewInspectionRequest
    ) async throws -> PDKStandardViewInspectionResult {
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

        let inputURL: URL
        do {
            inputURL = try PDKArtifactURLResolver().resolve(
                input,
                baseDirectoryPath: request.projectRootPath
            )
        } catch {
            let finding = PDKValidationFinding(
                severity: .blocker,
                code: "pdk.standard-view.input-path-invalid",
                message: "The standard-view artifact path could not be resolved: \(error.localizedDescription)",
                entity: input.path,
                suggestedActions: ["provide_project_root", "repair_standard_view_reference"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .blocked,
                findings: [finding],
                artifacts: [input]
            )
        }

        let sourceArtifact: ArtifactReference
        do {
            sourceArtifact = try PDKFoundationArtifactBridge.artifactReference(
                for: input,
                resolvedURL: inputURL
            )
            let integrity = LocalArtifactVerifier().verify(sourceArtifact)
            let integrityFindings = findings(for: integrity, entity: input.path)
            guard !integrityFindings.contains(where: { $0.severity == .blocker || $0.severity == .error }) else {
                return makeEnvelope(
                    request: request,
                    startedAt: startedAt,
                    status: .blocked,
                    findings: integrityFindings,
                    artifacts: [input]
                )
            }
        } catch let error as PDKFoundationArtifactError {
            let finding: PDKValidationFinding
            let status: PDKExecutionStatus
            switch error {
            case .missingDigest:
                finding = PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.digest-missing",
                    message: error.localizedDescription,
                    entity: input.path,
                    suggestedActions: ["rebuild_input_reference"]
                )
                status = .blocked
            case .missingByteCount:
                finding = PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.byte-count-missing",
                    message: error.localizedDescription,
                    entity: input.path,
                    suggestedActions: ["rebuild_input_reference"]
                )
                status = .blocked
            default:
                finding = PDKValidationFinding(
                    severity: .error,
                    code: "pdk.standard-view.integrity-failed",
                    message: error.localizedDescription,
                    entity: input.path,
                    suggestedActions: ["rebuild_input_reference", "check_file_permissions"]
                )
                status = .failed
            }
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: status,
                findings: [finding],
                artifacts: [input]
            )
        } catch {
            let finding = PDKValidationFinding(
                severity: .error,
                code: "pdk.standard-view.integrity-failed",
                message: "The standard-view artifact could not be represented or verified: \(error.localizedDescription)",
                entity: input.path,
                suggestedActions: ["rebuild_input_reference", "check_file_permissions"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                findings: [finding],
                artifacts: [input]
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: inputURL)
        } catch {
            let finding = PDKValidationFinding(
                severity: .error,
                code: "pdk.standard-view.input-unreadable",
                message: "The standard-view artifact could not be read: \(error.localizedDescription)",
                entity: inputURL.path,
                suggestedActions: ["restore_standard_view_artifact", "check_file_permissions"]
            )
            return makeEnvelope(
                request: request,
                startedAt: startedAt,
                status: .failed,
                findings: [finding],
                artifacts: [input]
            )
        }

        var findings: [PDKValidationFinding] = []
        do {
            var inspection = try parse(data: data, reference: input, format: request.format)
            inspection.sourceArtifact = sourceArtifact
            findings.append(contentsOf: semanticFindings(inspection: inspection, request: request))
            let hasBlocker = findings.contains { $0.severity == .blocker }
            let status: PDKExecutionStatus = hasBlocker ? .blocked : .completed
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

    private func findings(
        for integrity: ArtifactIntegrity,
        entity: String
    ) -> [PDKValidationFinding] {
        integrity.issues.map { issue in
            switch issue.code {
            case .missingFile:
                PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.input-missing",
                    message: "Standard-view input artifact is missing.",
                    entity: entity,
                    suggestedActions: ["restore_standard_view_artifact"]
                )
            case .byteCountMismatch:
                PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.byte-count-mismatch",
                    message: "Standard-view input bytes do not match the recorded byte count.",
                    entity: entity,
                    suggestedActions: ["rebuild_input_reference", "restore_immutable_artifact"]
                )
            case .digestMismatch:
                PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.digest-mismatch",
                    message: "Standard-view input bytes do not match the recorded SHA-256 digest.",
                    entity: entity,
                    suggestedActions: ["rebuild_input_reference", "restore_immutable_artifact"]
                )
            case .notRegularFile, .unreadableFile, .invalidLocation, .unsupportedDigestAlgorithm:
                PDKValidationFinding(
                    severity: .error,
                    code: "pdk.standard-view.digest-failed",
                    message: "Standard-view input integrity could not be verified: \(issue.code.rawValue).",
                    entity: entity,
                    suggestedActions: ["check_file_permissions", "restore_standard_view_artifact"]
                )
            }
        }
    }

    private func parse(
        data: Data,
        reference: ArtifactLocator,
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
        reference: ArtifactLocator
    ) throws -> PDKStandardViewIR {
        guard let text = String(data: data, encoding: .utf8) else {
            throw PDKStandardViewTextParseError.invalidEncoding
        }
        let lines = logicalTextLines(text)
        var modelNames: [String] = []
        var modelTypes: [String] = []
        var modelParameterNames: [String] = []
        var spiceModels: [PDKSpiceModel] = []
        var spiceSubcircuits: [PDKSpiceSubcircuit] = []
        var subcircuitNames: [String] = []
        var terminalNames: [String] = []
        var cornerNames: [String] = []
        var openSubcircuits: [(name: String, terminals: [String], parameterNames: [String], statementCount: Int)] = []
        var openLibrarySections: [String] = []
        var sawEnd = false

        for (lineNumber, line) in lines {
            let tokens = spiceDirectiveTokens(in: line)
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
                let modelName = tokens[1]
                let modelType = tokens[2]
                let parameters = parseSpiceAssignments(in: line)
                modelNames.append(modelName)
                modelTypes.append(modelType)
                modelParameterNames.append(contentsOf: parameters.map(\.name))
                spiceModels.append(PDKSpiceModel(
                    name: modelName,
                    type: modelType,
                    parameters: parameters
                ))
            case ".subckt":
                guard tokens.count >= 3 else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".subckt requires a name and at least one terminal"
                    )
                }
                let subcircuitName = tokens[1]
                let terminalTokens = tokens.dropFirst(2).prefix { token in
                    let lowercased = token.lowercased()
                    return lowercased != "params:" && lowercased != "param:" && !token.contains("=")
                }
                let terminals = Array(terminalTokens)
                guard !terminals.isEmpty else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".subckt requires at least one terminal before parameter declarations"
                    )
                }
                let parameterNames = parseSpiceAssignments(in: line).map(\.name)
                subcircuitNames.append(subcircuitName)
                terminalNames.append(contentsOf: terminals)
                openSubcircuits.append((
                    name: subcircuitName,
                    terminals: terminals,
                    parameterNames: parameterNames,
                    statementCount: 0
                ))
            case ".ends":
                guard let openSubcircuit = openSubcircuits.popLast() else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".ends has no matching .subckt"
                    )
                }
                if tokens.count > 1, tokens[1].caseInsensitiveCompare(openSubcircuit.name) != .orderedSame {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".ends name does not match the open subcircuit"
                    )
                }
                spiceSubcircuits.append(PDKSpiceSubcircuit(
                    name: openSubcircuit.name,
                    terminals: openSubcircuit.terminals,
                    parameterNames: openSubcircuit.parameterNames,
                    statementCount: openSubcircuit.statementCount
                ))
            case ".lib":
                if tokens.count > 1 {
                    let sectionName = (tokens.count > 2 ? tokens[tokens.count - 1] : tokens[1])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    cornerNames.append(sectionName)
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
                if tokens.count > 1, tokens[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    .caseInsensitiveCompare(openName) != .orderedSame {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .spice,
                        line: lineNumber,
                        reason: ".endl name does not match the open .lib section"
                    )
                }
            case ".param":
                modelParameterNames.append(contentsOf: parseSpiceAssignments(in: line).map(\.name))
            case ".func":
                if tokens.count > 1 {
                    modelParameterNames.append(tokens[1].split(separator: "(", maxSplits: 1).first.map(String.init) ?? tokens[1])
                }
            case ".end":
                sawEnd = true
            default:
                if !openSubcircuits.isEmpty {
                    openSubcircuits[openSubcircuits.index(before: openSubcircuits.endIndex)].statementCount += 1
                }
                continue
            }
        }

        if let openName = openSubcircuits.last?.name {
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
            spiceModels: spiceModels,
            spiceSubcircuits: spiceSubcircuits,
            pinNames: terminalNames,
            cornerNames: cornerNames,
            elementCount: lines.count,
            metadata: [
                "spice.modelCount": String(modelNames.count),
                "spice.modelTypeCount": String(modelTypes.count),
                "spice.modelParameterCount": String(modelParameterNames.count),
                "spice.subcircuitCount": String(subcircuitNames.count),
                "spice.numericParameterCount": String(spiceModels.flatMap(\.parameters).filter { $0.numericValue != nil }.count),
                "spice.endSeen": String(sawEnd)
            ]
        )
    }

    private func parseLiberty(
        data: Data,
        reference: ArtifactLocator
    ) throws -> PDKStandardViewIR {
        guard let text = String(data: data, encoding: .utf8) else {
            throw PDKStandardViewTextParseError.invalidEncoding
        }
        let lines = libertyLines(text)
        let root = try parseLibertyDocument(text)
        guard root.name.caseInsensitiveCompare("library") == .orderedSame else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: lines.first?.0 ?? 0,
                reason: "library declaration is missing"
            )
        }
        guard let libraryName = root.arguments.first, !libraryName.isEmpty else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: lines.first?.0 ?? 0,
                reason: "library declaration has no name"
            )
        }

        let cellNodes = root.children.filter { $0.name.caseInsensitiveCompare("cell") == .orderedSame }
        guard !cellNodes.isEmpty else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: lines.first?.0 ?? 0,
                reason: "at least one cell declaration is required"
            )
        }

        var cellNames: [String] = []
        var pinNames: [String] = []
        var libertyCells: [PDKLibertyCell] = []
        var libertyTimingArcs: [PDKLibertyTimingArc] = []
        var libertyTimingTables: [PDKLibertyTimingTable] = []
        for cellNode in cellNodes {
            guard let cellName = cellNode.arguments.first, !cellName.isEmpty else {
                throw PDKStandardViewTextParseError.malformed(
                    format: .liberty,
                    line: lines.first?.0 ?? 0,
                    reason: "cell declaration has no name"
                )
            }
            let pinNodes = cellNode.children.filter { $0.name.caseInsensitiveCompare("pin") == .orderedSame }
            let cellPinNames = pinNodes.compactMap { $0.arguments.first }
            cellNames.append(cellName)
            pinNames.append(contentsOf: cellPinNames)
            libertyCells.append(PDKLibertyCell(
                name: cellName,
                pinNames: cellPinNames,
                area: libertyScalar(cellNode.attributes["area"])
            ))

            for pinNode in pinNodes {
                guard let pinName = pinNode.arguments.first, !pinName.isEmpty else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .liberty,
                        line: lines.first?.0 ?? 0,
                        reason: "pin declaration has no name"
                    )
                }
                let timingNodes = pinNode.children.filter { $0.name.caseInsensitiveCompare("timing") == .orderedSame }
                for timingNode in timingNodes {
                    let relatedPinName = libertyAttributeText(timingNode.attributes["related_pin"])
                    let tables = timingNodesToTables(
                        cellName: cellName,
                        pinName: pinName,
                        relatedPinName: relatedPinName,
                        timingNode: timingNode
                    )
                    let arc = PDKLibertyTimingArc(
                        cellName: cellName,
                        pinName: pinName,
                        relatedPinName: relatedPinName,
                        timingType: libertyAttributeText(timingNode.attributes["timing_type"]),
                        timingSense: libertyAttributeText(timingNode.attributes["timing_sense"]),
                        tables: tables
                    )
                    libertyTimingArcs.append(arc)
                    libertyTimingTables.append(contentsOf: tables)
                }
            }
        }

        let timingRelatedPinNames = libertyTimingArcs.compactMap(\.relatedPinName)
        let cornerNames = [libraryName] + root.children
            .filter { $0.name.caseInsensitiveCompare("operating_conditions") == .orderedSame }
            .compactMap { $0.arguments.first }
        let unitDeclarations = root.attributes.reduce(into: [String: String]()) { result, pair in
            guard pair.key.contains("unit") else { return }
            if let value = libertyAttributeText(pair.value) {
                result[pair.key] = value
            }
        }
        let timingTableValueCount = libertyTimingTables.reduce(0) { $0 + $1.values.count }
        let completeTimingTableCount = libertyTimingTables.filter(\.hasCompleteNumericSemantics).count
        return PDKStandardViewIR(
            format: .liberty,
            source: reference,
            libraryName: libraryName,
            cellNames: cellNames,
            pinNames: pinNames,
            cornerNames: cornerNames,
            timingArcCount: libertyTimingArcs.count,
            timingRelatedPinNames: timingRelatedPinNames,
            timingTableValueCount: timingTableValueCount,
            libertyCells: libertyCells,
            libertyTimingArcs: libertyTimingArcs,
            libertyTimingTables: libertyTimingTables,
            unitDeclarations: unitDeclarations,
            elementCount: lines.count,
            metadata: [
                "liberty.cellCount": String(cellNames.count),
                "liberty.pinCount": String(pinNames.count),
                "liberty.timingArcCount": String(libertyTimingArcs.count),
                "liberty.timingRelatedPinCount": String(timingRelatedPinNames.count),
                "liberty.timingTableCount": String(libertyTimingTables.count),
                "liberty.timingTableCompleteCount": String(completeTimingTableCount),
                "liberty.timingTableValueCount": String(timingTableValueCount),
                "liberty.numericValueCount": String(timingTableValueCount)
            ]
        )
    }

    private func parseLibertyDocument(_ text: String) throws -> LibertyNode {
        let tokens = try tokenizeLiberty(text)
        guard !tokens.isEmpty else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: 1,
                reason: "the Liberty document is empty"
            )
        }
        var index = 0
        let rootName = tokens[index].value
        let rootLine = tokens[index].line
        index += 1
        let arguments = try parseLibertyArguments(tokens, index: &index)
        let root = try parseLibertyGroupBody(
            name: rootName,
            arguments: arguments,
            tokens: tokens,
            index: &index,
            line: rootLine
        )
        guard index == tokens.count else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: tokens[index].line,
                reason: "unexpected tokens after the top-level library group"
            )
        }
        return root
    }

    private func tokenizeLiberty(_ text: String) throws -> [LibertyToken] {
        let characters = Array(text)
        let punctuation: Set<Character> = ["(", ")", "{", "}", ":", ";", ","]
        var tokens: [LibertyToken] = []
        var index = 0
        var line = 1
        while index < characters.count {
            let character = characters[index]
            if character.isNewline {
                line += 1
                index += 1
                continue
            }
            if character.isWhitespace {
                index += 1
                continue
            }
            if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                index += 2
                while index < characters.count, !characters[index].isNewline {
                    index += 1
                }
                continue
            }
            if character == "/", index + 1 < characters.count, characters[index + 1] == "*" {
                let commentLine = line
                index += 2
                var closed = false
                while index < characters.count {
                    if characters[index].isNewline {
                        line += 1
                    }
                    if characters[index] == "*", index + 1 < characters.count, characters[index + 1] == "/" {
                        index += 2
                        closed = true
                        break
                    }
                    index += 1
                }
                guard closed else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .liberty,
                        line: commentLine,
                        reason: "block comment is not closed"
                    )
                }
                continue
            }
            if character == "\"" {
                let stringLine = line
                index += 1
                var value = ""
                var closed = false
                while index < characters.count {
                    let current = characters[index]
                    if current == "\\", index + 1 < characters.count {
                        value.append(characters[index + 1])
                        index += 2
                        continue
                    }
                    if current == "\"" {
                        index += 1
                        closed = true
                        break
                    }
                    if current.isNewline {
                        line += 1
                    }
                    value.append(current)
                    index += 1
                }
                guard closed else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .liberty,
                        line: stringLine,
                        reason: "quoted string is not closed"
                    )
                }
                tokens.append(LibertyToken(value: value, line: stringLine))
                continue
            }
            if punctuation.contains(character) {
                tokens.append(LibertyToken(value: String(character), line: line))
                index += 1
                continue
            }
            let tokenLine = line
            let start = index
            while index < characters.count {
                let current = characters[index]
                if current.isWhitespace || punctuation.contains(current) || current == "\"" {
                    break
                }
                if current == "/", index + 1 < characters.count,
                   (characters[index + 1] == "/" || characters[index + 1] == "*") {
                    break
                }
                index += 1
            }
            if start == index {
                index += 1
            } else {
                tokens.append(LibertyToken(
                    value: String(characters[start..<index]),
                    line: tokenLine
                ))
            }
        }
        return tokens
    }

    private func parseLibertyArguments(
        _ tokens: [LibertyToken],
        index: inout Int
    ) throws -> [String] {
        guard index < tokens.count, tokens[index].value == "(" else {
            return []
        }
        index += 1
        var arguments: [String] = []
        while index < tokens.count, tokens[index].value != ")" {
            if tokens[index].value != "," {
                arguments.append(tokens[index].value)
            }
            index += 1
        }
        guard index < tokens.count else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: tokens.last?.line ?? 1,
                reason: "parenthesized declaration is not closed"
            )
        }
        index += 1
        return arguments
    }

    private func parseLibertyGroupBody(
        name: String,
        arguments: [String],
        tokens: [LibertyToken],
        index: inout Int,
        line: Int
    ) throws -> LibertyNode {
        guard index < tokens.count, tokens[index].value == "{" else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: index < tokens.count ? tokens[index].line : line,
                reason: "group \(name) is missing an opening brace"
            )
        }
        index += 1
        var attributes: [String: [String]] = [:]
        var children: [LibertyNode] = []
        while index < tokens.count, tokens[index].value != "}" {
            let memberName = tokens[index].value
            let memberLine = tokens[index].line
            index += 1
            let memberArguments = try parseLibertyArguments(tokens, index: &index)
            if index < tokens.count, tokens[index].value == "{" {
                let child = try parseLibertyGroupBody(
                    name: memberName,
                    arguments: memberArguments,
                    tokens: tokens,
                    index: &index,
                    line: memberLine
                )
                children.append(child)
                continue
            }
            if index < tokens.count, tokens[index].value == ":" {
                index += 1
                var values: [String] = []
                while index < tokens.count, tokens[index].value != ";" {
                    if tokens[index].value == "}" {
                        throw PDKStandardViewTextParseError.malformed(
                            format: .liberty,
                            line: tokens[index].line,
                            reason: "attribute \(memberName) is not terminated by a semicolon"
                        )
                    }
                    if tokens[index].value != "," {
                        values.append(tokens[index].value)
                    }
                    index += 1
                }
                guard index < tokens.count else {
                    throw PDKStandardViewTextParseError.malformed(
                        format: .liberty,
                        line: memberLine,
                        reason: "attribute \(memberName) is not terminated by a semicolon"
                    )
                }
                index += 1
                attributes[memberName.lowercased()] = values
                continue
            }
            if index < tokens.count, tokens[index].value == ";" {
                index += 1
                attributes[memberName.lowercased()] = memberArguments
                continue
            }
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: memberLine,
                reason: "member \(memberName) is neither a group nor an attribute"
            )
        }
        guard index < tokens.count else {
            throw PDKStandardViewTextParseError.malformed(
                format: .liberty,
                line: line,
                reason: "group \(name) is not closed"
            )
        }
        index += 1
        return LibertyNode(
            name: name,
            arguments: arguments,
            attributes: attributes,
            children: children
        )
    }

    private func timingNodesToTables(
        cellName: String,
        pinName: String,
        relatedPinName: String?,
        timingNode: LibertyNode
    ) -> [PDKLibertyTimingTable] {
        let tableKinds: Set<String> = [
            "cell_rise", "cell_fall", "rise_transition", "fall_transition",
            "rise_constraint", "fall_constraint", "retaining_rise", "retaining_fall",
            "internal_power", "rise_power", "fall_power"
        ]
        return timingNode.children.compactMap { tableNode in
            let kind = tableNode.name.lowercased()
            guard tableKinds.contains(kind) else { return nil }
            let rawIndex1 = libertyListValues(tableNode.attributes["index_1"] ?? tableNode.attributes["index1"] ?? [])
            let rawIndex2 = libertyListValues(tableNode.attributes["index_2"] ?? tableNode.attributes["index2"] ?? [])
            let rawIndex3 = libertyListValues(tableNode.attributes["index_3"] ?? tableNode.attributes["index3"] ?? [])
            let rawValues = libertyListValues(tableNode.attributes["values"] ?? [])
            return PDKLibertyTimingTable(
                cellName: cellName,
                pinName: pinName,
                relatedPinName: relatedPinName,
                kind: kind,
                index1: libertyNumericValues(rawIndex1),
                index2: libertyNumericValues(rawIndex2),
                index3: libertyNumericValues(rawIndex3),
                values: libertyNumericValues(rawValues),
                rawIndex1: rawIndex1,
                rawIndex2: rawIndex2,
                rawIndex3: rawIndex3,
                rawValues: rawValues
            )
        }
    }

    private func libertyListValues(_ values: [String]) -> [String] {
        values.flatMap { value in
            value.split { $0.isWhitespace || $0 == "," }.map(String.init)
        }
    }

    private func libertyNumericValues(_ values: [String]) -> [Double] {
        values.compactMap { value in
            guard let number = Double(value), number.isFinite else { return nil }
            return number
        }
    }

    private func libertyAttributeText(_ values: [String]?) -> String? {
        guard let value = values?.first, !value.isEmpty else { return nil }
        return value
    }

    private func libertyScalar(_ values: [String]?) -> Double? {
        guard let value = libertyAttributeText(values),
              let number = Double(value),
              number.isFinite else {
            return nil
        }
        return number
    }

    private func spiceDirectiveTokens(in line: String) -> [String] {
        line.split { $0.isWhitespace || $0 == "," }
            .map(String.init)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "()")) }
            .filter { !$0.isEmpty }
    }

    private func parseSpiceAssignments(in line: String) -> [PDKSpiceParameter] {
        let characters = Array(line)
        var index = 0
        var parameters: [PDKSpiceParameter] = []
        while index < characters.count {
            guard isSpiceParameterNameCharacter(characters[index]) else {
                index += 1
                continue
            }
            let nameStart = index
            while index < characters.count, isSpiceParameterNameCharacter(characters[index]) {
                index += 1
            }
            let name = String(characters[nameStart..<index])
            while index < characters.count, characters[index].isWhitespace {
                index += 1
            }
            guard index < characters.count, characters[index] == "=" else {
                continue
            }
            index += 1
            while index < characters.count, characters[index].isWhitespace {
                index += 1
            }
            let valueStart = index
            if index < characters.count, characters[index] == "{" {
                var depth = 0
                while index < characters.count {
                    if characters[index] == "{" { depth += 1 }
                    if characters[index] == "}" {
                        depth -= 1
                        index += 1
                        if depth == 0 { break }
                        continue
                    }
                    index += 1
                }
            } else {
                while index < characters.count,
                      !characters[index].isWhitespace,
                      characters[index] != ")",
                      characters[index] != "," {
                    index += 1
                }
            }
            let rawValue = String(characters[valueStart..<index])
            guard !rawValue.isEmpty else { continue }
            parameters.append(makeSpiceParameter(name: name, rawValue: rawValue))
        }
        return parameters
    }

    private func isSpiceParameterNameCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "$" || character == "."
    }

    private func makeSpiceParameter(name: String, rawValue: String) -> PDKSpiceParameter {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directValue = Double(trimmed), directValue.isFinite {
            return PDKSpiceParameter(
                name: name,
                rawValue: trimmed,
                numericValue: directValue,
                isExpression: false
            )
        }
        let lowercased = trimmed.lowercased()
        let suffixes: [(String, Double)] = [
            ("meg", 1.0e6),
            ("mil", 25.4e-6),
            ("t", 1.0e12),
            ("g", 1.0e9),
            ("k", 1.0e3),
            ("m", 1.0e-3),
            ("u", 1.0e-6),
            ("n", 1.0e-9),
            ("p", 1.0e-12),
            ("f", 1.0e-15),
            ("a", 1.0e-18)
        ]
        for (suffix, multiplier) in suffixes where lowercased.hasSuffix(suffix) {
            let numberEnd = trimmed.index(trimmed.endIndex, offsetBy: -suffix.count)
            let numberText = String(trimmed[..<numberEnd])
            if let number = Double(numberText), number.isFinite {
                return PDKSpiceParameter(
                    name: name,
                    rawValue: trimmed,
                    numericValue: number * multiplier,
                    unitSuffix: String(trimmed[numberEnd...]),
                    isExpression: false
                )
            }
        }
        return PDKSpiceParameter(
            name: name,
            rawValue: trimmed,
            isExpression: true
        )
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

    private func makeMaskIR(
        library: IRLibrary,
        reference: ArtifactLocator,
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

        switch request.format {
        case .spice:
            for model in inspection.spiceModels {
                for parameter in model.parameters where parameter.numericValue == nil {
                    findings.append(PDKValidationFinding(
                        severity: .blocker,
                        code: "pdk.standard-view.spice-parameter-unsupported",
                        message: "SPICE model parameter \(parameter.name) is not a supported numeric value: \(parameter.rawValue).",
                        entity: "\(model.name).\(parameter.name)",
                        suggestedActions: ["resolve_spice_parameter_expression", "use_a_supported_model_view"]
                    ))
                }
            }
            if inspection.metadata["spice.endSeen"] != "true" {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.spice-end-missing",
                    message: "SPICE input does not contain a terminating .end statement.",
                    entity: request.assetID,
                    suggestedActions: ["repair_spice_artifact", "complete_spice_deck"]
                ))
            }
        case .liberty:
            if !inspection.libertyTimingArcs.isEmpty && inspection.libertyTimingTables.isEmpty {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.liberty-timing-table-missing",
                    message: "Liberty timing arcs are present without any supported timing table values.",
                    entity: request.assetID,
                    suggestedActions: ["add_liberty_timing_tables", "use_a_supported_liberty_view"]
                ))
            }
            if !inspection.libertyTimingTables.isEmpty && inspection.unitDeclarations["time_unit"] == nil {
                findings.append(PDKValidationFinding(
                    severity: .blocker,
                    code: "pdk.standard-view.liberty-time-unit-missing",
                    message: "Liberty timing tables are present without a declared time_unit.",
                    entity: request.assetID,
                    suggestedActions: ["declare_liberty_time_unit", "repair_liberty_library_header"]
                ))
            }
            for table in inspection.libertyTimingTables {
                if !table.hasCompleteNumericSemantics {
                    findings.append(PDKValidationFinding(
                        severity: .blocker,
                        code: "pdk.standard-view.liberty-table-value-unsupported",
                        message: "Liberty timing table \(table.kind) contains a non-numeric or missing index/value token.",
                        entity: "\(table.cellName).\(table.pinName).\(table.kind)",
                        suggestedActions: ["repair_liberty_numeric_table", "use_a_supported_liberty_view"]
                    ))
                } else if !table.hasConsistentDimensions {
                    findings.append(PDKValidationFinding(
                        severity: .blocker,
                        code: "pdk.standard-view.liberty-table-dimension-mismatch",
                        message: "Liberty timing table \(table.kind) value count does not match its index dimensions.",
                        entity: "\(table.cellName).\(table.pinName).\(table.kind)",
                        suggestedActions: ["repair_liberty_table_dimensions", "inspect_liberty_indices"]
                    ))
                }
            }
        case .lef, .gdsii, .oasis:
            break
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
        status: PDKExecutionStatus,
        findings: [PDKValidationFinding],
        artifacts: [ArtifactLocator] = [],
        inspection: PDKStandardViewIR? = nil
    ) -> PDKStandardViewInspectionResult {
        PDKStandardViewInspectionResult(
            schemaVersion: PDKStandardViewInspectionRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: findings.map(PDKStandardViewDiagnosticMapper.map),
            artifacts: artifacts,
            metadata: PDKExecutionMetadata(
                engineID: "PDKStandardViewInspection",
                implementationID: "LocalPDKStandardViewInspector",
                implementationVersion: "2",
                startedAt: startedAt,
                completedAt: clock.now()
            ),
            payload: PDKStandardViewInspectionPayload(
                isValid: status == .completed,
                assetID: request.assetID,
                inspection: inspection,
                findings: findings,
                parserID: parserID(for: request.format),
                parserVersion: parserVersion(for: request.format),
                limitations: [
                    "This inspection proves the supported canonical structural and detailed numeric semantics for the selected standard view.",
                    "Unsupported SPICE expressions and incomplete Liberty timing tables are blocked.",
                    "It does not establish foundry qualification or oracle correlation."
                ]
            )
        )
    }

    private func parserID(for format: PDKStandardViewFormat) -> String {
        switch format {
        case .lef, .gdsii, .oasis:
            "swift-mask-data.\(format.rawValue)"
        case .spice:
            "pdkkit.spice"
        case .liberty:
            "pdkkit.liberty"
        }
    }

    private func parserVersion(for format: PDKStandardViewFormat) -> String {
        switch format {
        case .lef, .gdsii, .oasis:
            "swift-mask-data-workspace"
        case .spice, .liberty:
            "detailed-v1"
        }
    }
}
