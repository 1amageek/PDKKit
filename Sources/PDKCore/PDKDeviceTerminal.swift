import Foundation

public struct PDKDeviceTerminal: Sendable, Hashable, Codable {
    public var name: String
    public var role: PDKTerminalRole
    public var order: Int

    public init(name: String, role: PDKTerminalRole, order: Int) {
        self.name = name
        self.role = role
        self.order = order
    }
}
