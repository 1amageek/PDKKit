import CircuiteFoundation
import PDKCore

struct PDKConsumptionWork: Sendable {
    let admission: PDKAdmissionWork
    init(_ resources: any PDKAdmissionResourceAccounting) { admission = .init(resources: resources) }
    var resources: any PDKAdmissionResourceAccounting { admission.resources }
    func run<T>(_ body: () throws(PDKProfileAdmissionError) -> T) throws(PDKProfileConsumptionError) -> T {
        do { return try body() } catch {
            if case .resource(let error) = error { throw .resource(error) }
            throw .invalidProjection
        }
    }
    func check() throws(PDKProfileConsumptionError) { try run { () throws(PDKProfileAdmissionError) -> Void in try admission.check() } }
    func step() throws(PDKProfileConsumptionError) { try run { () throws(PDKProfileAdmissionError) -> Void in try admission.step() } }
    func charge(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64) throws(PDKProfileConsumptionError) {
        try run { () throws(PDKProfileAdmissionError) -> Void in try admission.charge(dimension, amount) }
    }
    func reserve(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64) throws(PDKProfileConsumptionError) -> PDKAdmissionReservation {
        try run { () throws(PDKProfileAdmissionError) -> PDKAdmissionReservation in try admission.reserve(dimension, amount) }
    }
    func bytes(_ text: String) throws(PDKProfileConsumptionError) -> UInt64 {
        try run { () throws(PDKProfileAdmissionError) -> UInt64 in try admission.bytes(text) }
    }
    func capacity<T>(_ type: T.Type, _ count: Int, dimension: PDKAdmissionResourceDimension)
        throws(PDKProfileConsumptionError) -> PDKAdmissionReservation? {
        try run { () throws(PDKProfileAdmissionError) -> PDKAdmissionReservation? in try admission.capacity(type, count, dimension: dimension) }
    }
    func append<T: Sendable>(_ value: T, to collection: inout PDKAdmissionCollection<T>) throws(PDKProfileConsumptionError) {
        try run { () throws(PDKProfileAdmissionError) -> Void in try collection.append(value, work: admission) }
    }
    func equal(_ a: String, _ b: String) throws(PDKProfileConsumptionError) -> Bool {
        try run { () throws(PDKProfileAdmissionError) -> Bool in try admission.equal(a, b) }
    }
    func equal(_ a: String?, _ b: String?) throws(PDKProfileConsumptionError) -> Bool {
        try run { () throws(PDKProfileAdmissionError) -> Bool in try admission.equal(a, b) }
    }
    func equal(_ a: ArtifactReference, _ b: ArtifactReference) throws(PDKProfileConsumptionError) -> Bool {
        try run { () throws(PDKProfileAdmissionError) -> Bool in try admission.equal(a, b) }
    }
    func equal(_ a: PDKSourceDependency, _ b: PDKSourceDependency) throws(PDKProfileConsumptionError) -> Bool {
        try run { () throws(PDKProfileAdmissionError) -> Bool in try admission.equal(a, b) }
    }
    func equal(_ a: ContentDigest, _ b: ContentDigest) throws(PDKProfileConsumptionError) -> Bool {
        try step(); guard a.algorithm == b.algorithm else { return false }
        return try equal(a.hexadecimalValue, b.hexadecimalValue)
    }
    func equal(_ a: [String], _ b: [String]) throws(PDKProfileConsumptionError) -> Bool {
        try step(); guard a.count == b.count else { return false }
        for index in a.indices { if try !equal(a[index], b[index]) { return false } }; return true
    }
    func equal(_ a: PDKProfileSelection, _ b: PDKProfileSelection) throws(PDKProfileConsumptionError) -> Bool {
        guard try equal(a.requirementID, b.requirementID), try equal(a.cornerID, b.cornerID),
              try equal(a.selectedSection, b.selectedSection), try equal(a.assetIDs, b.assetIDs) else { return false }
        return try equal(a.sourceKeys, b.sourceKeys)
    }
    func equal(_ a: PDKProfileCorner, _ b: PDKProfileCorner) throws(PDKProfileConsumptionError) -> Bool {
        try step()
        guard a.pvt.process.nominal == b.pvt.process.nominal, a.pvt.voltage == b.pvt.voltage,
              a.pvt.temperatureCelsius == b.pvt.temperatureCelsius, try equal(a.cornerID, b.cornerID) else { return false }
        return try equal(a.pvt.process.name, b.pvt.process.name)
    }
    func equal(_ a: PDKConsumedSource, _ b: PDKConsumedSource) throws(PDKProfileConsumptionError) -> Bool {
        try step()
        guard a.occurrenceID == b.occurrenceID, a.parentOccurrenceID == b.parentOccurrenceID,
              try equal(a.sourceKey, b.sourceKey), try equal(a.reference, b.reference),
              try equal(a.cornerID, b.cornerID), try equal(a.selectedSection, b.selectedSection),
              try equal(a.preprocessingIdentity, b.preprocessingIdentity) else { return false }
        switch (a.incomingDependency, b.incomingDependency) {
        case (.none, .none): return true
        case (.some(let a), .some(let b)): return try equal(a, b)
        default: return false
        }
    }
    func equal(_ a: PDKConsumedMapping, _ b: PDKConsumedMapping) throws(PDKProfileConsumptionError) -> Bool {
        try step()
        guard a.occurrenceID == b.occurrenceID, a.layerNumber == b.layerNumber, a.layerPurpose == b.layerPurpose,
              try equal(a.factKind, b.factKind), try equal(a.name, b.name) else { return false }
        return try equal(a.terminals, b.terminals)
    }
    func value<T>(_ body: () throws(PDKProfileValueError) -> T) throws(PDKProfileConsumptionError) -> T {
        do { return try body() } catch {
            if case .resource(let resource) = error { throw .resource(resource) }; throw .value(error)
        }
    }
    func contains(_ value: String, in values: [String]) throws(PDKProfileConsumptionError) -> Bool {
        for candidate in values { if try equal(value, candidate) { return true } }; return false
    }
    func contains(_ value: Int, in values: PDKAdmissionCollection<Int>) throws(PDKProfileConsumptionError) -> Bool {
        for candidate in values { try step(); if candidate == value { return true } }; return false
    }
    func copy(_ text: String, owners: inout PDKAdmissionCollection<PDKAdmissionReservation>) throws(PDKProfileConsumptionError) -> String {
        let count = try bytes(text)
        if count > 0 { try append(reserve(.liveOwnedBytes, count), to: &owners) }
        try charge(.parserWork, count)
        let result = String(decoding: text.utf8, as: UTF8.self)
        try check(); return result
    }
}
