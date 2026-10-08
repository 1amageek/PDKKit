import Foundation

public struct PDKKitCLIInvocationResult: Sendable, Equatable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String
    public let profileResult: PDKProfileCommandResult?

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.profileResult = nil
    }
    init(profileResult: PDKProfileCommandResult) {
        exitCode = profileResult.exitCode; standardOutput = ""; standardError = ""
        self.profileResult = profileResult
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.exitCode == rhs.exitCode && lhs.standardOutput == rhs.standardOutput && lhs.standardError == rhs.standardError
            && lhs.profileResult === rhs.profileResult
    }
}
