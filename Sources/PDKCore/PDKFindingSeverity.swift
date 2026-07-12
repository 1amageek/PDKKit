import Foundation

public enum PDKFindingSeverity: String, Sendable, Hashable, Codable, CaseIterable {
    case info
    case warning
    case error
    case blocker
}
