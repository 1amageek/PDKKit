import CircuiteFoundation
import PDKProfileAdmission

public enum PDKStandardProfileInspection {
    public static func technologyRegistration(policyIdentity: String,
        decoder: any PDKStandardTechnologyDecoding = NativePDKStandardTechnologyDecoder())
        throws(PDKProfileAdmissionError) -> PDKProfileInspectorRegistration {
        try .init(format: .json, parserIdentity: NativePDKStandardProfileInspector.technologyParserIdentity,
            policyIdentity: policyIdentity,
            inspector: NativePDKStandardProfileInspector(format: .json, policyIdentity: policyIdentity, technologyDecoder: decoder))
    }
    public static func unsupportedRegistration(format: ArtifactFormat, policyIdentity: String)
        throws(PDKProfileAdmissionError) -> PDKProfileInspectorRegistration {
        guard format != .json, format != .spice else { throw .inspection(.unsupportedFormat) }
        return try .init(format: format, parserIdentity: NativePDKStandardProfileInspector.unsupportedParserIdentity,
            policyIdentity: policyIdentity, inspector: NativePDKStandardProfileInspector(format: format, policyIdentity: policyIdentity))
    }
}
