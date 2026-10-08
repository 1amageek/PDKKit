import Foundation
import Testing
import CircuiteFoundation
@testable import PDKCore

@Suite(.timeLimit(.minutes(1)))
struct ConsumptionValueTests {
    private func reference(_ digit: String = "1", kind: String = "pdk.spice") throws -> ArtifactReference {
        try ProfileValueTests().reference(digit, kind: kind)
    }
    private func root(_ id: UInt64 = 0, corner: String? = nil) throws -> PDKConsumedSource {
        try PDKConsumedSource(occurrenceID: id, sourceKey: "root", reference: reference(), cornerID: corner,
            selectedSection: nil, preprocessingIdentity: "parent.policy", parentOccurrenceID: nil, incomingDependency: nil)
    }
    private func edge(parentKey: String = "root", parentReference: ArtifactReference? = nil,
                      childKey: String = "child", childReference: ArtifactReference? = nil,
                      section: String? = "section", policy: String = "child.policy", order: UInt64 = 7) throws -> PDKSourceDependency {
        try PDKSourceDependency(parentSourceKey: parentKey, parentReference: parentReference ?? reference(),
            statementByteOffset: 1, statementOrdinal: order, directiveKind: "include", literalRoute: "child.sp",
            childSourceKey: childKey, childReference: childReference ?? reference("2"), selectedSection: section,
            preprocessingIdentity: policy, lexicalOrder: order)
    }
    private func child(_ id: UInt64 = 1, parentID: UInt64 = 0, corner: String? = nil,
                       incoming: PDKSourceDependency? = nil) throws -> PDKConsumedSource {
        try PDKConsumedSource(occurrenceID: id, sourceKey: "child", reference: reference("2"), cornerID: corner,
            selectedSection: "section", preprocessingIdentity: "child.policy", parentOccurrenceID: parentID,
            incomingDependency: incoming ?? edge())
    }
    private func corner(_ id: String = "tt") throws -> PDKProfileCorner {
        try PDKProfileCorner(cornerID: id, pvt: PDKPVTCondition(process: PDKProcessCorner(name: "typical", nominal: true),
            voltage: 1, temperatureCelsius: 25))
    }
    private func mapping(_ id: UInt64 = 0, name: String = "device", terminals: [String] = []) throws -> PDKConsumedMapping {
        try PDKConsumedMapping(occurrenceID: id, factKind: "devices", name: name, terminals: terminals,
            layerNumber: nil, layerPurpose: nil)
    }
    private func claim(_ sources: [PDKConsumedSource], mappings: [PDKConsumedMapping] = [],
                       corners: [PDKProfileCorner] = [], resources: (any PDKAdmissionResourceAccounting)? = nil) throws -> PDKConsumptionClaim {
        try PDKConsumptionClaim(stageRequirement: PDKConsumerRequirement(stageID: "simulation", requirementIDs: ["model"],
            cornerIDs: [], configurationIdentity: "fixture.configuration"), profileIdentity: reference("a").digest,
            expectedProjectionIdentity: reference("b").digest, actualSources: sources, actualMappings: mappings,
            actualCorners: corners, actualSelections: [], domainEvidenceReference: reference("c"), resources: resources)
    }
    private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
    private func data(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    @Test func repeatedContextsAndIndependentCornersRoundTripWithoutRenumberingEdges() throws {
        let sources = try [root(corner: "tt"), child(corner: "tt"), child(2, corner: "tt", incoming: edge(order: 11)), root(3, corner: "ss")]
        let records = try [mapping(0, terminals: ["drain", "gate", "source"]), mapping(1), mapping(2), mapping(3)]
        let value = try claim(sources, mappings: records, corners: [corner(), corner("ss")])
        let decoded = try JSONDecoder().decode(PDKConsumptionClaim.self, from: JSONEncoder().encode(value))
        #expect(decoded == value)
        #expect(decoded.actualSources.map(\.occurrenceID) == [0, 1, 2, 3])
        #expect(decoded.actualSources.compactMap(\.incomingDependency).map(\.lexicalOrder) == [7, 11])
        #expect(decoded.actualMappings[0].terminals == ["drain", "gate", "source"])
        let wire = try object(value)
        #expect(wire["schemaVersion"] as? Int == 2)
        let rootWire = try object(sources[0])
        #expect(rootWire["parentOccurrenceID"] is NSNull)
        #expect(rootWire["incomingDependency"] is NSNull)
        #expect(rootWire["selectedSection"] is NSNull)
        #expect(try object(records[0])["schemaVersion"] as? Int == 1)
    }
    @Test(arguments: ["source", "claim"])
    func oldConsumedSchemasAreRejectedWithoutDefaults(kind: String) throws {
        if kind == "source" {
            var wire = try object(root()); wire["schemaVersion"] = 1
            #expect(throws: PDKProfileValueError.unsupportedSchema(1)) { try JSONDecoder().decode(PDKConsumedSource.self, from: data(wire)) }
        } else {
            var wire = try object(claim([root()])); wire["schemaVersion"] = 1
            #expect(throws: PDKProfileValueError.unsupportedSchema(1)) { try JSONDecoder().decode(PDKConsumptionClaim.self, from: data(wire)) }
        }
    }
    @Test(arguments: ["occurrenceID", "cornerID", "parentOccurrenceID", "incomingDependency"])
    func newNullableSourceFieldsAreRequiredKeys(field: String) throws {
        var wire = try object(root()); wire.removeValue(forKey: field)
        #expect(throws: PDKProfileValueError.self) { try JSONDecoder().decode(PDKConsumedSource.self, from: data(wire)) }
    }
    @Test func mappingWireRequiresEveryDeclaredFieldAndRejectsUnknownFields() throws {
        let value = try mapping(terminals: ["d", "g", "s"])
        #expect(try JSONDecoder().decode(PDKConsumedMapping.self, from: JSONEncoder().encode(value)) == value)
        for field in ["occurrenceID", "factKind", "name", "terminals", "layerNumber", "layerPurpose"] {
            var wire = try object(value); wire.removeValue(forKey: field)
            #expect(throws: PDKProfileValueError.self) { try JSONDecoder().decode(PDKConsumedMapping.self, from: data(wire)) }
        }
        var wire = try object(value); wire["invented"] = true
        #expect(throws: PDKProfileValueError.self) { try JSONDecoder().decode(PDKConsumedMapping.self, from: data(wire)) }
        var claimWire = try object(claim([root()])); claimWire.removeValue(forKey: "actualMappings")
        #expect(throws: PDKProfileValueError.self) { try JSONDecoder().decode(PDKConsumptionClaim.self, from: data(claimWire)) }
    }
    @Test(arguments: ["key", "digest", "descriptor", "section", "policy"])
    func anIncomingEdgeMustMatchItsFullChildContext(mismatch: String) throws {
        let incoming: PDKSourceDependency
        switch mismatch {
        case "key": incoming = try edge(childKey: "other")
        case "digest": incoming = try edge(childReference: reference("3"))
        case "descriptor": incoming = try edge(childReference: reference("2", kind: "pdk.model"))
        case "section": incoming = try edge(section: "other")
        default: incoming = try edge(policy: "other")
        }
        #expect(throws: PDKProfileValueError.conflictingReference("Consumed incoming child context")) { try child(incoming: incoming) }
    }
    @Test func rootAndChildParentFieldsMustBePaired() throws {
        let parents: [UInt64?] = [nil, 0]
        for parent in parents {
            let incoming: PDKSourceDependency?
            if parent == nil { incoming = try edge() } else { incoming = nil }
            #expect(throws: PDKProfileValueError.noncanonicalEncoding("Consumed parent and dependency must be paired")) {
                try PDKConsumedSource(occurrenceID: 1, sourceKey: "child", reference: reference("2"), cornerID: nil,
                    selectedSection: "section", preprocessingIdentity: "child.policy", parentOccurrenceID: parent, incomingDependency: incoming)
            }
        }
    }
    @Test(arguments: ["duplicate", "gap", "self", "future", "huge", "parentKey", "parentDigest", "parentDescriptor"])
    func occurrencesRequireOrderedIDsAndTheExactPrecedingParent(mismatch: String) throws {
        let sources: [PDKConsumedSource]
        switch mismatch {
        case "duplicate": sources = try [root(), root()]
        case "gap": sources = try [root(), root(2)]
        case "self": sources = try [root(), child(parentID: 1)]
        case "future": sources = try [root(), child(parentID: 2)]
        case "huge": sources = try [root(), child(parentID: UInt64.max)]
        case "parentKey": sources = try [root(), child(incoming: edge(parentKey: "foreign"))]
        case "parentDigest": sources = try [root(), child(incoming: edge(parentReference: reference("9")))]
        default: sources = try [root(), child(incoming: edge(parentReference: reference(kind: "pdk.model")))]
        }
        #expect(throws: PDKProfileValueError.self) { try claim(sources) }
    }
    @Test func cornerMembershipAndChildPropagationAreCheckedIndependently() throws {
        #expect(throws: PDKProfileValueError.missingSelection("Consumed corner")) { try claim([root(corner: "unknown")]) }
        #expect(throws: PDKProfileValueError.conflictingReference("Consumed parent context")) {
            try claim([root(corner: "tt"), child(corner: "ss")], corners: [corner(), corner("ss")])
        }
        #expect(throws: PDKProfileValueError.conflictingReference("Consumed parent context")) {
            try claim([root(), child(corner: "tt")], corners: [corner()])
        }
        #expect(throws: PDKProfileValueError.self) { try claim([root(corner: "tt")], corners: [corner(), corner()]) }
    }
    @Test func mappingOccurrenceAndExactDuplicateChecksDoNotDeduplicateDistinctObservations() throws {
        let same = try mapping()
        #expect(throws: PDKProfileValueError.duplicateKey("Consumed mapping record")) { try claim([root()], mappings: [same, same]) }
        #expect(throws: PDKProfileValueError.missingSelection("Consumed mapping occurrence")) { try claim([root()], mappings: [mapping(UInt64.max)]) }
        let unrelated = try PDKConsumedMapping(occurrenceID: 0, factKind: "observation", name: "unrelated", terminals: [],
            layerNumber: -1, layerPurpose: nil)
        let value = try claim([root(), root(1)], mappings: [same, mapping(1), mapping(name: "other"), mapping(terminals: ["d", "g"]), unrelated])
        #expect(value.actualMappings.count == 5)
        let decoded = try JSONDecoder().decode(PDKConsumptionClaim.self, from: JSONEncoder().encode(value))
        #expect(decoded.actualMappings.last == unrelated)
        #expect(try claim([]).actualSources.isEmpty)
    }
    @Test func mappingStringsAndIndependentLayerFieldsPreserveEveryObservation() throws {
        let invalidStrings: [(String, String, [String])] = [("", "m", []), ("devices", " ", []), ("devices", "m", ["d", ""])]
        for (kind, name, terminals) in invalidStrings {
            #expect(throws: PDKProfileValueError.self) {
                try PDKConsumedMapping(occurrenceID: 0, factKind: kind, name: name, terminals: terminals, layerNumber: nil, layerPurpose: nil)
            }
        }
        let observations: [(Int?, PDKLayerPurpose?)] = [(-1, .drawing), (1, nil), (nil, .drawing), (nil, nil), (Int.min, nil), (Int.max, .other)]
        for (number, purpose) in observations {
            let value = try PDKConsumedMapping(occurrenceID: 0, factKind: "layers", name: "observed", terminals: [], layerNumber: number, layerPurpose: purpose)
            #expect(try JSONDecoder().decode(PDKConsumedMapping.self, from: JSONEncoder().encode(value)) == value)
        }
        let layer = try PDKConsumedMapping(occurrenceID: 0, factKind: "layers", name: "metal1", terminals: [], layerNumber: 0, layerPurpose: .drawing)
        #expect(try JSONDecoder().decode(PDKConsumedMapping.self, from: JSONEncoder().encode(layer)) == layer)
    }
    @Test func constructionAndStrictDecodePreserveAccountingFailures() throws {
        let sources = try [root(), child()], records = try [mapping(), mapping(1)]
        let value = try claim(sources, mappings: records)
        let baseline = ProfileTestAccounting()
        #expect(try claim(sources, mappings: records, resources: baseline) == value)
        #expect(baseline.used(.parserWork) > 0)
        #expect(baseline.used(.temporaryBytes) == 0)
        let limited = ProfileTestAccounting(); limited.limit(.parserWork, to: baseline.used(.parserWork) - 1)
        #expect(throws: PDKProfileValueError.self) { try claim(sources, mappings: records, resources: limited) }
        let cancelled = ProfileTestAccounting(); cancelled.failure = .cancelled
        #expect(throws: PDKProfileValueError.resource(.cancelled)) { try claim(sources, resources: cancelled) }
        let decoder = JSONDecoder(); decoder.userInfo[PDKAdmissionDecodingContext.accountingKey] = cancelled
        #expect(throws: PDKProfileValueError.resource(.cancelled)) { try decoder.decode(PDKConsumptionClaim.self, from: JSONEncoder().encode(value)) }
    }
}
