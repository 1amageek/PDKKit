import Foundation

public struct PDKCorpusSuiteValidationReport: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var findings: [PDKValidationFinding]

    public init(isValid: Bool, findings: [PDKValidationFinding]) {
        self.isValid = isValid
        self.findings = findings
    }
}
