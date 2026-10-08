public struct PDKProfileSourceCoverage: Sendable {
    public enum Meaning: Sendable { case leaf, complete }
    public let input: PDKProfileSourceInput
    public let observedSection: String?
    public let meaning: Meaning
    public let evidenceIdentity: String
    public let activeDependencies: [PDKProfileDependencyEvent]
    public let inactiveStatementOffsets: [UInt64]
    public init(input: PDKProfileSourceInput, meaning: Meaning, observedSection: String?, evidenceIdentity: String,
                activeDependencies: [PDKProfileDependencyEvent], inactiveStatementOffsets: [UInt64]) {
        self.observedSection = observedSection
        self.input = input; self.meaning = meaning; self.evidenceIdentity = evidenceIdentity
        self.activeDependencies = activeDependencies; self.inactiveStatementOffsets = inactiveStatementOffsets
    }
}
