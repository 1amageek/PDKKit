import Foundation

public struct PDKSpiceModel: Sendable, Hashable, Codable {
    public var name: String
    public var type: String
    public var parameters: [PDKSpiceParameter]

    public init(
        name: String,
        type: String,
        parameters: [PDKSpiceParameter] = []
    ) {
        self.name = name
        self.type = type
        self.parameters = parameters.sorted { $0.name < $1.name }
    }
}
