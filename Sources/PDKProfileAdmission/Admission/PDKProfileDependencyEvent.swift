import PDKCore

public struct PDKProfileDependencyEvent: Sendable {
    public let edge: PDKSourceDependency
    public let parentContext: PDKProfileSourceContext
    public let childContext: PDKProfileSourceContext
    internal let parentNodeID: Int
    internal let childNodeID: Int
    internal init(edge: PDKSourceDependency, parent: PDKProfileSourceContext, child: PDKProfileSourceContext, parentNodeID: Int, childNodeID: Int) {
        self.parentNodeID = parentNodeID; self.childNodeID = childNodeID
        self.edge = edge; parentContext = parent; childContext = child
    }
}
