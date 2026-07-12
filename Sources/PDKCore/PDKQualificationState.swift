import Foundation

public enum PDKQualificationState: String, Sendable, Hashable, Codable, CaseIterable {
    case unverified
    case smokeChecked
    case oracleCorrelated
    case processQualified
}
