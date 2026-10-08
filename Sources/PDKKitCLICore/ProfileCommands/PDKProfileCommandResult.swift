/// A checked delivery result. Copies retain the original output and input owners.
public final class PDKProfileCommandResult: Sendable {
    public let exitCode: Int32
    public let output: PDKOwnedProfileOutput?
    public let isStandardError: Bool
    public let failure: PDKProfileCommandError?
    public let deliveryFailure: PDKProfileOutputError?
    public let terminalDeliveryFailure: PDKProfileOutputError?
    private let owners: PDKProfileCommandOwners?
    internal init(exitCode: Int32, output: PDKOwnedProfileOutput?, isStandardError: Bool,
                  failure: PDKProfileCommandError?, deliveryFailure: PDKProfileOutputError?,
                  terminalDeliveryFailure: PDKProfileOutputError? = nil,
                  owners: PDKProfileCommandOwners? = nil) {
        self.exitCode = exitCode; self.output = output; self.isStandardError = isStandardError
        self.failure = failure; self.deliveryFailure = deliveryFailure; self.owners = owners
        self.terminalDeliveryFailure = terminalDeliveryFailure
    }
}
