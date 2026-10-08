import PDKCore

public struct PDKProfileAdmissionRequest: Sendable {
    public let definition: PDKProfileExactBinding
    public let manifest: PDKProfileExactBinding
    public let roots: [PDKProfileAuthorizedRoot]
    public let sources: [PDKProfileSourceBinding]
    public let budget: PDKAdmissionBudget
    public let inspectionPolicyIdentity: String
    public init(definition: PDKProfileExactBinding, manifest: PDKProfileExactBinding,
                roots: [PDKProfileAuthorizedRoot], sources: [PDKProfileSourceBinding],
                budget: PDKAdmissionBudget, inspectionPolicyIdentity: String) {
        self.definition = definition; self.manifest = manifest; self.roots = roots
        self.sources = sources; self.budget = budget; self.inspectionPolicyIdentity = inspectionPolicyIdentity
    }
}
