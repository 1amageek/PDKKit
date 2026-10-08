import PDKCore

public struct PDKProfileSourceInspectionRequest: Sendable {
    public let input: PDKProfileSourceInput
    public let requirementID: String?
    public let view: PDKViewKind?
    public let corner: PDKProfileCorner?
    public let demandedFactKinds: [String]
    public let inspectionPolicyIdentity: String
    internal init(input: PDKProfileSourceInput, requirementID: String?, view: PDKViewKind?,
                  corner: PDKProfileCorner?, demandedFactKinds: [String], policy: String) {
        self.input = input; self.requirementID = requirementID; self.view = view
        self.corner = corner; self.demandedFactKinds = demandedFactKinds; inspectionPolicyIdentity = policy
    }
}
