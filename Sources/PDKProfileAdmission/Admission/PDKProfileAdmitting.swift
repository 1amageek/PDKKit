import PDKCore

public protocol PDKProfileAdmitting: Sendable {
    func admit(_ request: PDKProfileAdmissionRequest) async throws(PDKProfileAdmissionError) -> AdmittedPDKProfile
    /// The trusted caller supplies matching budget configuration and owns final close.
    /// Preserve its original deadline and cumulative counters throughout admission.
    func admit(_ request: PDKProfileAdmissionRequest, resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileAdmissionError) -> AdmittedPDKProfile
}
