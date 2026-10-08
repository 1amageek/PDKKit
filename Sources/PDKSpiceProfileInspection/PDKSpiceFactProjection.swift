import CoreSpiceIO
import PDKCore
import PDKProfileAdmission

/// Checked translation; raw grammar fields retain their lower owner until final copy.
struct PDKSpiceFactProjection {
    let bridge: PDKSpiceResourceBridge
    let resolver: PDKSpiceOccurrenceResolver
    private var retained = SPICEAccountedCollection<SPICESourceStorageReservation>(storageKind: .temporaryBytes)
    private var expressions = SPICEAccountedCollection<SPICEOwnedExpressionText>(storageKind: .temporaryBytes)
    private var mappings = SPICEAccountedCollection<PDKProfileMappingFact>(storageKind: .temporaryBytes)
    private var temperatures = SPICEAccountedCollection<PDKSourceTemperatureFact>(storageKind: .temporaryBytes)

    init(bridge: PDKSpiceResourceBridge, resolver: PDKSpiceOccurrenceResolver) {
        self.bridge = bridge; self.resolver = resolver
    }
    mutating func project(_ netlist: ParsedNetlist, request: PDKProfileSourceInspectionRequest,
                          policy: String) async throws -> PDKProfileSourceFacts {
        try await models(netlist.models)
        try await subcircuits(netlist.subcircuits)
        try await controls(netlist.controls)
        let entries = await resolver.snapshot()
        var events = SPICEAccountedCollection<PDKProfileDependencyEvent>(storageKind: .temporaryBytes)
        // Core events are the traversal authority; the provider owns each approved edge.
        for event in netlist.dependencyEvents {
            try bridge.charge(.tokens, units: 1)
            guard let parentID = event.parentOccurrenceID, let childID = event.childOccurrenceID,
                  let offset = event.statementByteOffset, let ordinal = event.statementOrdinal,
                  let identity = event.preprocessingIdentity else { throw PDKProfileInspectionError.invalidFacts }
            let parent = try await resolver.entry(parentID), child = try await resolver.entry(childID)
            guard let approved = child.input.incomingEvent,
                  try bridge.equal(parent.input.sourceKey, event.parentCaptureID ?? ""),
                  try bridge.equal(child.input.sourceKey, event.childCaptureID ?? ""),
                  approved.edge.statementByteOffset == offset, approved.edge.statementOrdinal == ordinal,
                  try bridge.equal(approved.edge.preprocessingIdentity, identity),
                  try bridge.equal(approved.edge.literalRoute, event.path) else {
                throw PDKProfileInspectionError.invalidFacts
            }
            try events.append(approved, resources: bridge)
        }
        var coverage = SPICEAccountedCollection<PDKProfileSourceCoverage>(storageKind: .temporaryBytes)
        for entry in entries {
            var active = SPICEAccountedCollection<PDKProfileDependencyEvent>(storageKind: .temporaryBytes)
            for event in netlist.dependencyEvents {
                try bridge.charge(.tokens, units: 1)
                guard event.parentOccurrenceID == entry.occurrence, let childID = event.childOccurrenceID else { continue }
                let child = try await resolver.entry(childID)
                guard let approved = child.input.incomingEvent else { throw PDKProfileInspectionError.invalidFacts }
                try active.append(approved, resources: bridge)
            }
            var inactive = SPICEAccountedCollection<UInt64>(storageKind: .temporaryBytes)
            for event in netlist.preprocessingEvents {
                try bridge.charge(.tokens, units: 1)
                guard let location = event.location,
                      try bridge.equal(location.file, entry.diagnosticName.text) else { continue }
                guard event.selection != .unresolved else { throw PDKProfileInspectionError.unsupportedSemantics }
                if event.selection == .inactive {
                    let offset = try entry.document.originalByteOffset(at: location, resources: bridge)
                    try inactive.append(offset, resources: bridge)
                }
            }
            let activeRaw = try raw(active), inactiveRaw = try raw(inactive)
            try coverage.append(.init(input: entry.input,
                meaning: active.isEmpty && inactive.isEmpty ? .leaf : .complete,
                observedSection: entry.input.context.selectedSection,
                evidenceIdentity: LocalPDKSpiceProfileInspector.parserIdentity,
                activeDependencies: activeRaw, inactiveStatementOffsets: inactiveRaw), resources: bridge)
        }
        let mappingRaw = try raw(mappings), temperatureRaw = try raw(temperatures)
        let coverageRaw = try raw(coverage), eventRaw = try raw(events)
        defer { withExtendedLifetime((retained, expressions, entries, mappings, temperatures, coverage, events)) {} }
        return try PDKProfileSourceFacts(input: request.input,
            parserIdentity: LocalPDKSpiceProfileInspector.parserIdentity, policyIdentity: policy,
            mappings: mappingRaw, pvt: [], temperatures: temperatureRaw, coverage: coverageRaw,
            events: eventRaw, unsupportedFactKinds: [], lostFactKinds: [], resources: bridge.resources)
    }
    private mutating func raw<Element: Sendable>(_ values: SPICEAccountedCollection<Element>) throws -> [Element] {
        let copy = try bridge.array(values)
        try retained.append(copy.owner, resources: bridge); return copy.values
    }
    private mutating func models(_ values: [ParsedModel]) async throws {
        for model in values {
            try bridge.charge(.tokens, units: 1)
            guard let origin = model.origin, let occurrence = origin.occurrenceID,
                  let offset = origin.statementByteOffset, let ordinal = origin.statementOrdinal else {
                throw PDKProfileInspectionError.invalidFacts
            }
            let entry = try await resolver.entry(occurrence)
            guard try bridge.equal(origin.captureID, entry.input.sourceKey) else { throw PDKProfileInspectionError.invalidFacts }
            var parameters = SPICEAccountedCollection<PDKProfileModelParameter>(storageKind: .temporaryBytes)
            for (name, value) in model.parameters {
                let converted = try parameter(value)
                try parameters.append(.init(name: name, value: converted), resources: bridge)
                if try bridge.equal(name, "tnom") {
                    try temperature(value, kind: "modelNominalTemperature", entry: entry)
                }
            }
            let detail = PDKProfileModelDetail(type: model.type.rawValue, level: model.level, parameters: try raw(parameters))
            try mappings.append(.init(input: entry.input, factKind: "devices", name: model.name,
                model: detail, origin: .init(statementByteOffset: offset, statementOrdinal: ordinal,
                    line: origin.location.line, column: origin.location.column)), resources: bridge)
        }
    }
    private mutating func subcircuits(_ values: [ParsedSubcircuit]) async throws {
        for subcircuit in values {
            try bridge.charge(.tokens, units: 1)
            guard let origin = subcircuit.origin, let occurrence = origin.occurrenceID,
                  let offset = origin.statementByteOffset, let ordinal = origin.statementOrdinal else {
                throw PDKProfileInspectionError.invalidFacts
            }
            let entry = try await resolver.entry(occurrence)
            guard try bridge.equal(origin.captureID, entry.input.sourceKey) else { throw PDKProfileInspectionError.invalidFacts }
            try mappings.append(.init(input: entry.input, factKind: "devices", name: subcircuit.name,
                terminals: subcircuit.ports, origin: .init(statementByteOffset: offset,
                    statementOrdinal: ordinal, line: origin.location.line, column: origin.location.column)), resources: bridge)
            try await models(subcircuit.body.models)
            try await subcircuits(subcircuit.body.subcircuits)
        }
    }
    private mutating func parameter(_ value: ParsedParameterValue) throws -> PDKProfileParameterValue {
        try bridge.charge(.tokens, units: 1)
        switch value {
        case .numeric(let number): return .numeric(number)
        case .numericVector(let numbers): return .numericVector(numbers)
        case .string(let text): return .string(text)
        case .boolean(let flag): return .boolean(flag)
        case .expression(let expression):
            let text = try SPICEExpressionFormatter().format(expression: expression, resources: bridge)
            try expressions.append(text, resources: bridge)
            return .expression(text.text)
        }
    }
    private mutating func controls(_ values: [ParsedControlStatement]) async throws {
        for control in values {
            try bridge.charge(.tokens, units: 1)
            let value: ParsedParameterValue, location: SourceLocation?, kind: String
            switch control {
            case .temp(let observed, let at): value = observed; location = at; kind = "operatingTemperature"
            case .option(let name, let observed, let at):
                if try bridge.equal(name, "tnom") { kind = "circuitNominalTemperature" }
                else if try bridge.equal(name, "temp") { kind = "operatingTemperature" }
                else { continue }
                guard let observed else { throw PDKProfileInspectionError.unsupportedSemantics }
                value = observed; location = at
            default: continue
            }
            guard let location, let entry = try await resolver.entry(file: location.file) else {
                throw PDKProfileInspectionError.invalidFacts
            }
            try temperature(value, kind: kind, entry: entry)
        }
    }
    private mutating func temperature(_ value: ParsedParameterValue, kind: String,
                                     entry: PDKSpiceOccurrenceResolver.Entry) throws {
        guard case .numeric(let number) = value else { throw PDKProfileInspectionError.unsupportedSemantics }
        let fact = try PDKSourceTemperatureFact(kind: kind, temperatureCelsius: number,
            sourceReference: entry.input.reference, evidenceIdentity: LocalPDKSpiceProfileInspector.parserIdentity,
            resources: bridge.resources)
        try temperatures.append(fact, resources: bridge)
    }
}
