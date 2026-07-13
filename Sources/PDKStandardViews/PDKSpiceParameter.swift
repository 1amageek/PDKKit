import Foundation

public struct PDKSpiceParameter: Sendable, Hashable, Codable {
    public var name: String
    public var rawValue: String
    public var numericValue: Double?
    public var unitSuffix: String?
    public var isExpression: Bool

    public init(
        name: String,
        rawValue: String,
        numericValue: Double? = nil,
        unitSuffix: String? = nil,
        isExpression: Bool = false
    ) {
        self.name = name
        self.rawValue = rawValue
        self.numericValue = numericValue
        self.unitSuffix = unitSuffix
        self.isExpression = isExpression
    }
}
