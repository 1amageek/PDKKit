import PDKCore

/// Internal projection evidence; support occurrences never disappear from admission.
struct PDKProfileRootOccurrence: Sendable {
    let nodeID: Int
    let selection: PDKProfileSelection?
    let isMandatorySupport: Bool
}
