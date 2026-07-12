import Foundation

public enum PDKCapabilityStatus: String, Sendable, Hashable, Codable, CaseIterable {
    case available
    case blocked
    case notEvaluated
}
