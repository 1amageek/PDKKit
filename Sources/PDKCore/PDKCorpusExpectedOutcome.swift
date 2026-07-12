import Foundation

public enum PDKCorpusExpectedOutcome: String, Sendable, Hashable, Codable, CaseIterable {
    case valid
    case blocked
    case failed
}
