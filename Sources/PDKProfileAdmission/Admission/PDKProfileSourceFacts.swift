import PDKCore

/// Checked output storage; inspectors pre-admit their original parse/scratch storage.
public struct PDKProfileSourceFacts: Sendable {
    public let input: PDKProfileSourceInput
    public let parserIdentity: String
    public let policyIdentity: String
    public let mappings: [PDKProfileMappingFact]
    public let pvt: [PDKSourcePVTFact]
    public let temperatures: [PDKSourceTemperatureFact]
    public let coverage: [PDKProfileSourceCoverage]
    public let events: [PDKProfileDependencyEvent]
    public let unsupportedFactKinds: [String]
    public let lostFactKinds: [String]
    private let reservations: [PDKAdmissionReservation]

    public init(input: PDKProfileSourceInput, parserIdentity: String, policyIdentity: String,
                mappings: [PDKProfileMappingFact], pvt: [PDKSourcePVTFact], temperatures: [PDKSourceTemperatureFact],
                coverage: [PDKProfileSourceCoverage], events: [PDKProfileDependencyEvent],
                unsupportedFactKinds: [String], lostFactKinds: [String],
                resources: any PDKAdmissionResourceAccounting) throws(PDKProfileInspectionError) {
        let work = PDKAdmissionWork(resources: resources)
        var owners: [PDKAdmissionReservation] = []
        do throws(PDKProfileAdmissionError) {
            func copy<T>(_ values: [T], _ transform: (T) throws(PDKProfileAdmissionError) -> T)
                throws(PDKProfileAdmissionError) -> [T] {
                if let lease = try work.capacity(T.self, values.count) { owners.append(lease) }
                var output: [T] = []; output.reserveCapacity(values.count)
                for value in values { try work.step(); output.append(try transform(value)) }; return output
            }
            func text(_ value: String) throws(PDKProfileAdmissionError) -> String {
                let count = try work.bytes(value)
                if count > 0 { owners.append(try work.reserve(.liveOwnedBytes, count)) }
                try work.charge(.parserWork, count)
                let output = String(decoding: value.utf8, as: UTF8.self)
                try work.check(); return output
            }
            self.input = input
            self.parserIdentity = try text(parserIdentity); self.policyIdentity = try text(policyIdentity)
            self.mappings = try copy(mappings) { (value) throws(PDKProfileAdmissionError) in
                PDKProfileMappingFact(input: value.input, factKind: try text(value.factKind), name: try text(value.name),
                    terminals: try copy(value.terminals, text), layerNumber: value.layerNumber, layerPurpose: value.layerPurpose)
            }
            self.pvt = try copy(pvt) { (value) throws(PDKProfileAdmissionError) in
                var condition = value.pvt; condition.process.name = try text(condition.process.name)
                let kind = try text(value.kind), evidence = try text(value.evidenceIdentity)
                do throws(PDKProfileValueError) { return try PDKSourcePVTFact(kind: kind, pvt: condition,
                    sourceReference: value.sourceReference, evidenceIdentity: evidence, resources: resources) }
                catch { throw .selection(error) }
            }
            self.temperatures = try copy(temperatures) { (value) throws(PDKProfileAdmissionError) in
                let kind = try text(value.kind), evidence = try text(value.evidenceIdentity)
                do throws(PDKProfileValueError) { return try PDKSourceTemperatureFact(kind: kind, temperatureCelsius: value.temperatureCelsius,
                    sourceReference: value.sourceReference, evidenceIdentity: evidence, resources: resources) }
                catch { throw .selection(error) }
            }
            self.coverage = try copy(coverage) { (value) throws(PDKProfileAdmissionError) in
                let section: String?
                if let original = value.observedSection { section = try text(original) } else { section = nil }
                return PDKProfileSourceCoverage(input: value.input, meaning: value.meaning, observedSection: section, evidenceIdentity: try text(value.evidenceIdentity),
                    activeDependencies: try copy(value.activeDependencies) { $0 },
                    inactiveStatementOffsets: try copy(value.inactiveStatementOffsets) { $0 })
            }
            self.events = try copy(events) { $0 }
            self.unsupportedFactKinds = try copy(unsupportedFactKinds, text)
            self.lostFactKinds = try copy(lostFactKinds, text)
            self.reservations = owners; try work.check()
        } catch {
            if case .resource(let error) = error { throw .resource(error) }; throw .invalidFacts
        }
    }
}
