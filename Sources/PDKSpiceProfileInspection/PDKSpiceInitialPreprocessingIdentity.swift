import CoreSpiceIO

/// Keep this handle while consuming its raw identity in bounded work.
public struct PDKSpiceInitialPreprocessingIdentity: Sendable {
    public let identity: String
    private let environment: SPICEPreprocessingEnvironment
    internal init(environment: SPICEPreprocessingEnvironment) {
        identity = environment.identity; self.environment = environment
    }
}
