import Foundation

public enum PDKTerminalRole: String, Sendable, Hashable, Codable, CaseIterable {
    case input
    case output
    case bidirectional
    case power
    case ground
    case bulk
    case substrate
    case clock
    case other
}
