import CircuiteFoundation
import PDKCore

/// Retains checked inputs and evidence identity; it does not grant domain capability.
public struct PDKMatchedConsumption: Sendable {
    public let projection: PDKStageProjection
    public let domainEvidenceReference: ArtifactReference
    private let storage: PDKAdmissionCollection<PDKAdmissionReservation>
    internal init(projection: PDKStageProjection, evidence: ArtifactReference,
                  storage: PDKAdmissionCollection<PDKAdmissionReservation>) {
        self.projection = projection; domainEvidenceReference = evidence; self.storage = storage
    }
}

public func matchPDKConsumption(_ claim: PDKConsumptionClaim, against projection: PDKStageProjection,
                                resources: any PDKAdmissionResourceAccounting)
    throws(PDKProfileConsumptionError) -> PDKMatchedConsumption {
    try PDKConsumptionComparison(projection: projection, work: .init(resources)).match(claim)
}
