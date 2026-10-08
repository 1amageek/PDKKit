import PDKCore

/// Reads operational evidence without authorizing work or changing invocation quotas.
public protocol PDKAdmissionResourceObserving: Sendable {
    func snapshot() throws(PDKAdmissionResourceError) -> PDKAdmissionResourceSnapshot
}
