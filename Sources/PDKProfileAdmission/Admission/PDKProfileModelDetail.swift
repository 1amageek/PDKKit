/// Actual model declaration semantics; no inferred terminals or analysis defaults.
public struct PDKProfileModelDetail: Sendable, Equatable {
    public let type: String
    public let level: Int?
    public let parameters: [PDKProfileModelParameter]
    public init(type: String, level: Int?, parameters: [PDKProfileModelParameter]) {
        self.type = type; self.level = level; self.parameters = parameters
    }
}
