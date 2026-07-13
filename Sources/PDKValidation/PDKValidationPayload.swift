import Foundation
import XcircuitePackage
import PDKCore

public struct PDKValidationPayload: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var missingRequirements: [String]
    public var findings: [PDKValidationFinding]
    public var resolvedAssets: [PDKResolvedAsset]
    public var standardViewResults: [PDKStandardViewValidationResult]
    public var ruleDeckResults: [PDKRuleDeckValidationResult]
    public var qualificationScope: PDKQualificationScope?
    public var capabilityReport: PDKCapabilityReport?

    public init(
        isValid: Bool,
        missingRequirements: [String],
        findings: [PDKValidationFinding] = [],
        resolvedAssets: [PDKResolvedAsset] = [],
        standardViewResults: [PDKStandardViewValidationResult] = [],
        ruleDeckResults: [PDKRuleDeckValidationResult] = [],
        qualificationScope: PDKQualificationScope? = nil,
        capabilityReport: PDKCapabilityReport? = nil
    ) {
        self.isValid = isValid
        self.missingRequirements = missingRequirements
        self.findings = findings
        self.resolvedAssets = resolvedAssets
        self.standardViewResults = standardViewResults
        self.ruleDeckResults = ruleDeckResults
        self.qualificationScope = qualificationScope
        self.capabilityReport = capabilityReport
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isValid = try container.decodeIfPresent(Bool.self, forKey: .isValid) ?? false
        missingRequirements = try container.decodeIfPresent([String].self, forKey: .missingRequirements) ?? []
        findings = try container.decodeIfPresent([PDKValidationFinding].self, forKey: .findings) ?? []
        resolvedAssets = try container.decodeIfPresent([PDKResolvedAsset].self, forKey: .resolvedAssets) ?? []
        standardViewResults = try container.decodeIfPresent([PDKStandardViewValidationResult].self, forKey: .standardViewResults) ?? []
        ruleDeckResults = try container.decodeIfPresent([PDKRuleDeckValidationResult].self, forKey: .ruleDeckResults) ?? []
        qualificationScope = try container.decodeIfPresent(PDKQualificationScope.self, forKey: .qualificationScope)
        capabilityReport = try container.decodeIfPresent(PDKCapabilityReport.self, forKey: .capabilityReport)
    }

    private enum CodingKeys: String, CodingKey {
        case isValid
        case missingRequirements
        case findings
        case resolvedAssets
        case standardViewResults
        case ruleDeckResults
        case qualificationScope
        case capabilityReport
    }
}
