import Foundation

public struct PDKKitCLIDiagnosticOutput: Sendable, Equatable, Codable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
