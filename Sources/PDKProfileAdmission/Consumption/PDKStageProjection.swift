import CircuiteFoundation
import PDKCore

/// Checked stage inputs retain the entire admitted parent, including mandatory support.
public struct PDKStageProjection: Sendable {
    public let profile: AdmittedPDKProfile
    public let requirement: PDKConsumerRequirement
    public let identity: ContentDigest
    public let inputs: PDKAdmissionCollection<PDKProfileSourceInput>
    public let sources: PDKAdmissionCollection<PDKConsumedSource>
    public let corners: PDKAdmissionCollection<PDKProfileCorner>
    public let selections: PDKAdmissionCollection<PDKProfileSelection>
    public let mappingRequirements: PDKAdmissionCollection<PDKStageMappingRequirement>
    internal let knownMappings: PDKAdmissionCollection<PDKConsumedMapping>
    private let storage: PDKAdmissionCollection<PDKAdmissionReservation>
    internal init(profile: AdmittedPDKProfile, requirement: PDKConsumerRequirement, identity: ContentDigest,
                  inputs: PDKAdmissionCollection<PDKProfileSourceInput>, sources: PDKAdmissionCollection<PDKConsumedSource>,
                  corners: PDKAdmissionCollection<PDKProfileCorner>, selections: PDKAdmissionCollection<PDKProfileSelection>,
                  mappings: PDKAdmissionCollection<PDKStageMappingRequirement>, known: PDKAdmissionCollection<PDKConsumedMapping>,
                  storage: PDKAdmissionCollection<PDKAdmissionReservation>) {
        self.profile = profile; self.requirement = requirement; self.identity = identity; self.inputs = inputs
        self.sources = sources; self.corners = corners; self.selections = selections; mappingRequirements = mappings
        knownMappings = known; self.storage = storage
    }
}

public func projectPDKProfile(_ profile: AdmittedPDKProfile, for requirement: PDKConsumerRequirement,
                              resources: any PDKAdmissionResourceAccounting)
    throws(PDKProfileConsumptionError) -> PDKStageProjection {
    try PDKStageProjectionBuilder(profile: profile, requested: requirement, work: .init(resources)).build()
}
