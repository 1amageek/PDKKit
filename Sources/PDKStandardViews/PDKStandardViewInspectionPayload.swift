import Foundation
import PDKCore

public struct PDKStandardViewInspectionPayload: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var assetID: String
    public var inspection: PDKStandardViewIR?
    public var findings: [PDKValidationFinding]
    public var parserID: String
    public var parserVersion: String
    public var limitations: [String]

    public init(
        isValid: Bool,
        assetID: String,
        inspection: PDKStandardViewIR? = nil,
        findings: [PDKValidationFinding] = [],
        parserID: String,
        parserVersion: String,
        limitations: [String] = []
    ) {
        self.isValid = isValid
        self.assetID = assetID
        self.inspection = inspection
        self.findings = findings
        self.parserID = parserID
        self.parserVersion = parserVersion
        self.limitations = limitations
    }
}
