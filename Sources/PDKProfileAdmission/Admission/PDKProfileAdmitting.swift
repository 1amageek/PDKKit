public protocol PDKProfileAdmitting: Sendable {
    func admit(_ request: PDKProfileAdmissionRequest) async throws(PDKProfileAdmissionError) -> AdmittedPDKProfile
}
