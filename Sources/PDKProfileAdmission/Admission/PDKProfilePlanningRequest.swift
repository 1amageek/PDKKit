import CircuiteFoundation
import PDKCore

public struct PDKProfilePlanningRequest: Sendable {
    public let definition: PDKProfileDefinition
    public let manifest: PDKManifest
    public let manifestReference: ArtifactReference
    public let resources: any PDKAdmissionResourceAccounting
    public init(definition: PDKProfileDefinition, manifest: PDKManifest,
                manifestReference: ArtifactReference, resources: any PDKAdmissionResourceAccounting) {
        self.definition = definition; self.manifest = manifest
        self.manifestReference = manifestReference; self.resources = resources
    }
}
