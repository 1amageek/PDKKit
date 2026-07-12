import Foundation
import XcircuitePackage
import PDKCore

public struct PDKValidationPayload: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var missingRequirements: [String]
    public var findings: [PDKValidationFinding]
    public var resolvedAssets: [PDKResolvedAsset]
    public var qualificationScope: PDKQualificationScope?
    public var capabilityReport: PDKCapabilityReport?

    public init(
        isValid: Bool,
        missingRequirements: [String],
        findings: [PDKValidationFinding] = [],
        resolvedAssets: [PDKResolvedAsset] = [],
        qualificationScope: PDKQualificationScope? = nil,
        capabilityReport: PDKCapabilityReport? = nil
    ) {
        self.isValid = isValid
        self.missingRequirements = missingRequirements
        self.findings = findings
        self.resolvedAssets = resolvedAssets
        self.qualificationScope = qualificationScope
        self.capabilityReport = capabilityReport
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isValid = try container.decodeIfPresent(Bool.self, forKey: .isValid) ?? false
        missingRequirements = try container.decodeIfPresent([String].self, forKey: .missingRequirements) ?? []
        findings = try container.decodeIfPresent([PDKValidationFinding].self, forKey: .findings) ?? []
        resolvedAssets = try container.decodeIfPresent([PDKResolvedAsset].self, forKey: .resolvedAssets) ?? []
        qualificationScope = try container.decodeIfPresent(PDKQualificationScope.self, forKey: .qualificationScope)
        capabilityReport = try container.decodeIfPresent(PDKCapabilityReport.self, forKey: .capabilityReport)
    }

    private enum CodingKeys: String, CodingKey {
        case isValid
        case missingRequirements
        case findings
        case resolvedAssets
        case qualificationScope
        case capabilityReport
    }
}
