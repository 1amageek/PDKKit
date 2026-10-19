import PDKCore
import PDKDiscovery
import PDKSourceCapture
import TechIR

/// The audited TechIR family uses decoder-owned scalars, arrays and dictionaries;
/// its Codable initializers assign fields without independent derived storage.
public struct NativePDKStandardTechnologyDecoder: PDKStandardTechnologyDecoding {
    private struct Field: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    public init() {}

    public func decodeTechnology(_ source: CapturedPDKSource, resources: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<IRTechLibrary> {
        try NativePDKBoundedDocumentDecoder().decodeAudited(IRTechLibrary.self, source: source,
            accounting: resources, rejectUnknownFields: true) { decoder in
            // Container creation checks every root field before the standard type
            // is decoded. Nested static-key containers receive the same strict mode.
            let fields = try decoder.container(keyedBy: Field.self)
            for field in fields.allKeys {
                guard try Self.known(field.stringValue, resources: resources) else {
                    throw PDKBoundedDecodeError.unsupportedValue("Unknown technology root field")
                }
            }
            let metadata = try fields.decode([String: String].self, forKey: Field(stringValue: "metadata"))
            guard metadata.isEmpty else { throw PDKBoundedDecodeError.unsupportedValue("Technology metadata is unsupported") }
        }
    }
    private static func known(_ field: String, resources: any PDKAdmissionResourceAccounting) throws -> Bool {
        try equal(field, "name", resources: resources) || equal(field, "dbuPerMicron", resources: resources)
            || equal(field, "layers", resources: resources) || equal(field, "vias", resources: resources)
            || equal(field, "sites", resources: resources) || equal(field, "designRules", resources: resources)
            || equal(field, "enclosureRules", resources: resources) || equal(field, "extensionRules", resources: resources)
            || equal(field, "minimumCutRules", resources: resources) || equal(field, "antennaRules", resources: resources)
            || equal(field, "metadata", resources: resources)
            || equal(field, "manufacturingGrid", resources: resources)
            || equal(field, "unitDeclarations", resources: resources)
            || equal(field, "hasDatabaseUnitsDeclaration", resources: resources)
            || equal(field, "obstructionSpacingUsesMinimumWidth", resources: resources)
            || equal(field, "propertyDefinitions", resources: resources)
            || equal(field, "viaGenerationRules", resources: resources)
    }
    private static func equal(_ left: String, _ right: String, resources: any PDKAdmissionResourceAccounting) throws -> Bool {
        var a = left.utf8.makeIterator(), b = right.utf8.makeIterator()
        while true {
            try resources.check()
            _ = try resources.reserve(PDKAdmissionCost(dimension: .parserWork, amount: 1))
            let x = a.next(), y = b.next()
            guard x == y else { return false }
            if x == nil { return true }
        }
    }
}
