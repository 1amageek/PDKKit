import Foundation
import PDKCore

public struct PDKOracleViewComparison: Sendable, Hashable, Codable {
    public var assetID: String
    public var format: PDKStandardViewFormat
    public var isMatch: Bool
    public var observed: PDKStandardViewIR?
    public var findings: [PDKValidationFinding]

    public init(
        assetID: String,
        format: PDKStandardViewFormat,
        isMatch: Bool,
        observed: PDKStandardViewIR? = nil,
        findings: [PDKValidationFinding] = []
    ) {
        self.assetID = assetID
        self.format = format
        self.isMatch = isMatch
        self.observed = observed
        self.findings = findings
    }
}
