import Foundation
import CircuiteFoundation
import PDKCore

public struct PDKOracleComparisonPayload: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var oracleID: String
    public var pdkDigest: String
    public var oracleArtifact: ArtifactReference?
    public var comparisons: [PDKOracleViewComparison]
    public var findings: [PDKValidationFinding]
    public var limitations: [String]

    public init(
        isValid: Bool,
        oracleID: String,
        pdkDigest: String,
        oracleArtifact: ArtifactReference? = nil,
        comparisons: [PDKOracleViewComparison] = [],
        findings: [PDKValidationFinding] = [],
        limitations: [String] = []
    ) {
        self.isValid = isValid
        self.oracleID = oracleID
        self.pdkDigest = pdkDigest
        self.oracleArtifact = oracleArtifact
        self.comparisons = comparisons
        self.findings = findings
        self.limitations = limitations
    }
}
