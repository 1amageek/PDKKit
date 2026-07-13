import Foundation

public struct PDKLibertyCell: Sendable, Hashable, Codable {
    public var name: String
    public var pinNames: [String]
    public var area: Double?

    public init(
        name: String,
        pinNames: [String] = [],
        area: Double? = nil
    ) {
        self.name = name
        self.pinNames = Array(Set(pinNames)).sorted()
        self.area = area
    }
}
