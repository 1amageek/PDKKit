public protocol PDKProfileOutputDelivering: Sendable {
    func deliver(_ output: PDKOwnedProfileOutput, to sink: any PDKProfileOutputSink)
        throws(PDKProfileOutputError) -> PDKDeliveredProfileOutput
}
