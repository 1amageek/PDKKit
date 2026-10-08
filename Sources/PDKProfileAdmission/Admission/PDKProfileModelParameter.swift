public struct PDKProfileModelParameter: Sendable, Equatable {
    public let name: String
    public let value: PDKProfileParameterValue
    public init(name: String, value: PDKProfileParameterValue) { self.name = name; self.value = value }
}
