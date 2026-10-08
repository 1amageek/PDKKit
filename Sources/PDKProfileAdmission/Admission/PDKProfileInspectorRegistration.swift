import CircuiteFoundation

public struct PDKProfileInspectorRegistration: Sendable {
    public let format: ArtifactFormat
    public let parserIdentity: String
    public let policyIdentity: String
    public let inspector: any PDKProfileSourceInspecting
    public init(format: ArtifactFormat, parserIdentity: String, policyIdentity: String,
                inspector: any PDKProfileSourceInspecting) throws(PDKProfileAdmissionError) {
        guard !parserIdentity.isEmpty, !policyIdentity.isEmpty else { throw .policyMismatch }
        self.format = format; self.parserIdentity = parserIdentity; self.policyIdentity = policyIdentity; self.inspector = inspector
    }
}
