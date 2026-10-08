import PDKCore

/// Draft evidence. Keep this owner while consuming raw graph fields in bounded work.
public struct PDKSpiceCandidateGraph: Sendable {
    public let parserIdentity: String
    public let policyIdentity: String
    public let initialPreprocessingIdentity: String
    public let sources: [PDKSpiceCandidateSource]
    public let dependencies: [PDKSourceDependency]
    public let occurrences: [PDKSpiceCandidateOccurrence]
    private let retainedOwner: any Sendable
    internal init(policyIdentity: String, initialPreprocessingIdentity: String, sources: [PDKSpiceCandidateSource],
                  dependencies: [PDKSourceDependency], occurrences: [PDKSpiceCandidateOccurrence], retaining owner: any Sendable) {
        parserIdentity = LocalPDKSpiceProfileInspector.parserIdentity
        self.policyIdentity = policyIdentity; self.initialPreprocessingIdentity = initialPreprocessingIdentity
        self.sources = sources; self.dependencies = dependencies; self.occurrences = occurrences; retainedOwner = owner
    }
}
