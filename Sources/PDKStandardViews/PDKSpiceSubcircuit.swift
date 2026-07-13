import Foundation

public struct PDKSpiceSubcircuit: Sendable, Hashable, Codable {
    public var name: String
    public var terminals: [String]
    public var parameterNames: [String]
    public var statementCount: Int

    public init(
        name: String,
        terminals: [String],
        parameterNames: [String] = [],
        statementCount: Int = 0
    ) {
        self.name = name
        self.terminals = terminals
        self.parameterNames = Array(Set(parameterNames)).sorted()
        self.statementCount = statementCount
    }
}
