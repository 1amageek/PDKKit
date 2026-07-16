import Foundation
import CircuiteFoundation
import PDKCore

public struct PDKValidationPayload: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var missingRequirements: [String]
    public var findings: [PDKValidationFinding]
    public var resolvedAssets: [PDKResolvedAsset]
    public var standardViewResults: [PDKStandardViewValidationResult]
    public var ruleDeckResults: [PDKRuleDeckValidationResult]
    public var capabilityReport: PDKCapabilityReport?

    public init(
        isValid: Bool,
        missingRequirements: [String],
        findings: [PDKValidationFinding] = [],
        resolvedAssets: [PDKResolvedAsset] = [],
        standardViewResults: [PDKStandardViewValidationResult] = [],
        ruleDeckResults: [PDKRuleDeckValidationResult] = [],
        capabilityReport: PDKCapabilityReport? = nil
    ) {
        self.isValid = isValid
        self.missingRequirements = missingRequirements
        self.findings = findings
        self.resolvedAssets = resolvedAssets
        self.standardViewResults = standardViewResults
        self.ruleDeckResults = ruleDeckResults
        self.capabilityReport = capabilityReport
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isValid = try container.decode(Bool.self, forKey: .isValid)
        missingRequirements = try container.decode([String].self, forKey: .missingRequirements)
        findings = try container.decode([PDKValidationFinding].self, forKey: .findings)
        resolvedAssets = try container.decode([PDKResolvedAsset].self, forKey: .resolvedAssets)
        standardViewResults = try container.decode([PDKStandardViewValidationResult].self, forKey: .standardViewResults)
        ruleDeckResults = try container.decode([PDKRuleDeckValidationResult].self, forKey: .ruleDeckResults)
        capabilityReport = try container.decodeIfPresent(PDKCapabilityReport.self, forKey: .capabilityReport)
    }

    private enum CodingKeys: String, CodingKey {
        case isValid
        case missingRequirements
        case findings
        case resolvedAssets
        case standardViewResults
        case ruleDeckResults
        case capabilityReport
    }
}
