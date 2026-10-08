import CircuiteFoundation
import PDKCore

/// The payload boundary; operational observations are appended by the output owner.
struct PDKProfileCommandEnvelope: Encodable {
    let schemaVersion = 1
    let command: String
    let scope: String
    let terminalStatus: String
    let reason: String?
    let completedPhase: String
    let bootstrapReference: ArtifactReference
    let bootstrapAcquisition: PDKBudgetAcquisitionObservations
    let definitionReference: ArtifactReference?
    let manifestReference: ArtifactReference?
    let inspectionPolicyIdentity: String?
    let definition: PDKProfileDefinition?
    let plan: PDKProfilePlan?
    let claim: PDKProfileClaim?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, command, scope, terminalStatus, reason, completedPhase, bootstrapReference,
             bootstrapAcquisition, definitionReference, manifestReference, inspectionPolicyIdentity, definition, plan, claim
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion); try c.encode(command, forKey: .command)
        try c.encode(scope, forKey: .scope); try c.encode(terminalStatus, forKey: .terminalStatus)
        try c.encode(reason, forKey: .reason); try c.encode(completedPhase, forKey: .completedPhase)
        try c.encode(bootstrapReference, forKey: .bootstrapReference)
        try c.encode(bootstrapAcquisition, forKey: .bootstrapAcquisition)
        try c.encode(definitionReference, forKey: .definitionReference); try c.encode(manifestReference, forKey: .manifestReference)
        try c.encode(inspectionPolicyIdentity, forKey: .inspectionPolicyIdentity)
        try c.encode(definition, forKey: .definition); try c.encode(claim, forKey: .claim)
        if let plan {
            var value = c.nestedContainer(keyedBy: PlanKeys.self, forKey: .plan)
            try value.encode(plan.definition, forKey: .definition)
            try value.encode(plan.manifestReference, forKey: .manifestReference)
            try value.encode(plan.corners, forKey: .corners); try value.encode(plan.selections, forKey: .selections)
            try value.encode(plan.roots, forKey: .roots); try value.encode(plan.mandatorySupportSourceKeys, forKey: .mandatorySupportSourceKeys)
        } else { try c.encodeNil(forKey: .plan) }
    }
    private enum PlanKeys: String, CodingKey { case definition, manifestReference, corners, selections, roots, mandatorySupportSourceKeys }
}
