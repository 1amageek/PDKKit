import Foundation
import PDKCore

public struct PDKManifestViewInspectionPayload: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var assetID: String
    public var pdkDigest: String
    public var inspection: PDKStandardViewInspectionPayload?
    public var binding: PDKStandardViewBindingReport?
    public var findings: [PDKValidationFinding]
    public var limitations: [String]

    public init(
        isValid: Bool,
        assetID: String,
        pdkDigest: String,
        inspection: PDKStandardViewInspectionPayload? = nil,
        binding: PDKStandardViewBindingReport? = nil,
        findings: [PDKValidationFinding] = [],
        limitations: [String] = []
    ) {
        self.isValid = isValid
        self.assetID = assetID
        self.pdkDigest = pdkDigest
        self.inspection = inspection
        self.binding = binding
        self.findings = findings
        self.limitations = limitations
    }
}
