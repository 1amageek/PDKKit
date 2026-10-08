/// A checked delivery result. Command success and accountant close remain caller-owned.
public struct PDKDeliveredProfileOutput: Sendable {
    public let output: PDKOwnedProfileOutput
    internal init(output: PDKOwnedProfileOutput) { self.output = output }
}
