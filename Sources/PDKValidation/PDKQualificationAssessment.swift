import Foundation
import PDKCore

public struct PDKQualificationAssessment: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var state: PDKQualificationState
    public var processID: String
    public var version: String
    public var pdkDigest: String
    public var corpusID: String?
    public var oracleID: String?
    public var evidenceIDs: [String]
    public var findings: [PDKValidationFinding]
    public var limitations: [String]

    public init(
        isValid: Bool,
        state: PDKQualificationState,
        processID: String,
        version: String,
        pdkDigest: String,
        corpusID: String? = nil,
        oracleID: String? = nil,
        evidenceIDs: [String] = [],
        findings: [PDKValidationFinding] = [],
        limitations: [String] = []
    ) {
        self.isValid = isValid
        self.state = state
        self.processID = processID
        self.version = version
        self.pdkDigest = pdkDigest
        self.corpusID = corpusID
        self.oracleID = oracleID
        self.evidenceIDs = evidenceIDs
        self.findings = findings
        self.limitations = limitations
    }
}
