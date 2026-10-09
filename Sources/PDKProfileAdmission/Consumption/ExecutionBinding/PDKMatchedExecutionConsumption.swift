import CircuiteFoundation
import PDKCore

/// Checked binding retains source observations; it grants no domain execution capability.
public struct PDKMatchedExecutionConsumption: Sendable {
    public let consumption: PDKMatchedConsumption
    public let bindingIdentity: ContentDigest
    public let executionInputIdentity: ContentDigest
    public let configurationIdentity: String
    public let grammarPolicyIdentity: String
    public let sources: PDKAdmissionCollection<PDKConsumedSource>
    public let sourceBindings: PDKAdmissionCollection<PDKExecutionSourceBinding>
    public let entries: PDKAdmissionCollection<PDKExecutionEntry>
    private let storage: PDKAdmissionCollection<PDKAdmissionReservation>
    internal init(consumption: PDKMatchedConsumption, bindingIdentity: ContentDigest,
                  executionInputIdentity: ContentDigest, configurationIdentity: String, grammarPolicyIdentity: String,
                  sources: PDKAdmissionCollection<PDKConsumedSource>, bindings: PDKAdmissionCollection<PDKExecutionSourceBinding>,
                  entries: PDKAdmissionCollection<PDKExecutionEntry>, storage: PDKAdmissionCollection<PDKAdmissionReservation>) {
        self.consumption = consumption; self.bindingIdentity = bindingIdentity
        self.executionInputIdentity = executionInputIdentity; self.configurationIdentity = configurationIdentity
        self.grammarPolicyIdentity = grammarPolicyIdentity; self.sources = sources; sourceBindings = bindings
        self.entries = entries; self.storage = storage
    }
}

public func matchPDKExecutionConsumption(_ claim: PDKExecutionConsumptionClaim,
    against projection: PDKStageProjection, observed: PDKExecutionSourceObservation,
    resources: any PDKAdmissionResourceAccounting) throws(PDKProfileConsumptionError) -> PDKMatchedExecutionConsumption {
    try PDKExecutionConsumptionComparison(projection: projection, observed: observed, work: .init(resources)).match(claim)
}
