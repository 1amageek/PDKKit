/// Physical declaration coordinates observed by the grammar in the mapping input.
public struct PDKProfilePhysicalOrigin: Sendable, Equatable {
    public let statementByteOffset: UInt64
    public let statementOrdinal: UInt64
    public let line: Int
    public let column: Int
    public init(statementByteOffset: UInt64, statementOrdinal: UInt64, line: Int, column: Int) {
        self.statementByteOffset = statementByteOffset; self.statementOrdinal = statementOrdinal
        self.line = line; self.column = column
    }
}
