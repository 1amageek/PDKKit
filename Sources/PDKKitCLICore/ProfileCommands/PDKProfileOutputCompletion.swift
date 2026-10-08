import PDKCore
import Synchronization

/// Reserved before payload work; static terminal bytes survive a refused preparation.
public struct PDKProfileOutputCompletion: Sendable {
    internal let owner: Owner
    public var terminalOutput: PDKOwnedProfileOutput { owner.terminal }
    internal init(owner: Owner) { self.owner = owner }

    internal final class Owner: Sendable {
        let resources: any PDKAdmissionResourceAccounting
        let policy: PDKProfileOutputCompletionPolicy
        let terminal: PDKOwnedProfileOutput
        let scratch: PDKAdmissionReservation
        private let prepared = Mutex(false)
        init(resources: any PDKAdmissionResourceAccounting, policy: PDKProfileOutputCompletionPolicy,
             terminal: PDKOwnedProfileOutput, scratch: PDKAdmissionReservation) {
            self.resources = resources; self.policy = policy; self.terminal = terminal; self.scratch = scratch
        }
        func take() throws(PDKProfileOutputError) {
            try prepared.withLock { (prepared) throws(PDKProfileOutputError) in
                guard !prepared else { throw .completionAlreadyUsed }
                prepared = true
            }
        }
    }
}
