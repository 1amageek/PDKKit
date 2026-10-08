public protocol PDKProfileDependencyResolving: Sendable {
    func resolve(_ request: PDKProfileDependencyRequest) async throws(PDKProfileAdmissionError) -> PDKProfileSourceInput
}
