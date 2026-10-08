/// Actual parse-entry context; occurrence identity is local to this observed graph.
public struct PDKSpiceCandidateOccurrence: Sendable {
    public let occurrenceID: UInt64
    public let parentOccurrenceID: UInt64?
    public let sourceKey: String
    public let logicalRoute: String
    public let selectedSection: String?
    public let preprocessingIdentity: String
    public let inactiveStatementOffsets: [UInt64]
    internal init(occurrenceID: UInt64, parentOccurrenceID: UInt64?, sourceKey: String, logicalRoute: String,
                  selectedSection: String?, preprocessingIdentity: String, inactiveStatementOffsets: [UInt64]) {
        self.occurrenceID = occurrenceID; self.parentOccurrenceID = parentOccurrenceID
        self.sourceKey = sourceKey; self.logicalRoute = logicalRoute; self.selectedSection = selectedSection
        self.preprocessingIdentity = preprocessingIdentity; self.inactiveStatementOffsets = inactiveStatementOffsets
    }
}
