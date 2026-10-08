import PDKCore

public protocol PDKProfilePlanning: Sendable {
    func plan(_ request: PDKProfilePlanningRequest) throws(PDKProfileAdmissionError) -> PDKProfilePlan
}
