import PDKCore

public struct LocalPDKProfilePlanner: PDKProfilePlanning {
    public init() {}
    public func plan(_ request: PDKProfilePlanningRequest) throws(PDKProfileAdmissionError) -> PDKProfilePlan {
        do { return try PDKProfilePlan(definition: request.definition, manifest: request.manifest,
            manifestReference: request.manifestReference, resources: request.resources) }
        catch { throw .selection(error) }
    }
}
