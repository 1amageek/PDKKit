import CircuiteFoundation
import PDKSourceCapture

/// Created only by checked admission or its invocation-owned resolver.
public struct PDKProfileSourceInput: Sendable {
    public let context: PDKProfileSourceContext
    public let capture: CapturedPDKSource
    public let logicalRoute: String
    public let incomingEvent: PDKProfileDependencyEvent?
    public var sourceKey: String { context.sourceKey }
    public var reference: ArtifactReference { capture.reference }
    internal let nodeID: Int
    internal let authority: PDKProfileInputAuthority
    internal let ancestry: PDKAdmissionCollection<PDKProfileSourceContext>
    internal init(context: PDKProfileSourceContext, capture: CapturedPDKSource, logicalRoute: String,
                  incomingEvent: PDKProfileDependencyEvent?, authority: PDKProfileInputAuthority,
                  ancestry: PDKAdmissionCollection<PDKProfileSourceContext>, nodeID: Int) {
        self.nodeID = nodeID
        self.context = context; self.capture = capture; self.logicalRoute = logicalRoute
        self.incomingEvent = incomingEvent; self.authority = authority; self.ancestry = ancestry
    }
}
