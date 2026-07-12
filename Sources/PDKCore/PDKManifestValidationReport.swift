import Foundation

public struct PDKManifestValidationReport: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var findings: [PDKValidationFinding]

    public init(isValid: Bool, findings: [PDKValidationFinding] = []) {
        self.isValid = isValid
        self.findings = findings
    }

    public var hasBlockers: Bool {
        findings.contains { $0.severity == .blocker }
    }
}
