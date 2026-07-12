import Foundation
import PDKCore

public struct PDKStandardViewBindingReport: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var mappingID: String?
    public var expectedLayerNames: [String]
    public var observedLayerNames: [String]
    public var missingLayerNames: [String]
    public var expectedPhysicalLayerNumbers: [Int]
    public var observedPhysicalLayerNumbers: [Int]
    public var missingPhysicalLayerNumbers: [Int]
    public var expectedCellNames: [String]
    public var observedCellNames: [String]
    public var missingCellNames: [String]
    public var expectedCornerNames: [String]
    public var observedCornerNames: [String]
    public var missingCornerNames: [String]
    public var findings: [PDKValidationFinding]

    public init(
        isValid: Bool,
        mappingID: String? = nil,
        expectedLayerNames: [String] = [],
        observedLayerNames: [String] = [],
        missingLayerNames: [String] = [],
        expectedPhysicalLayerNumbers: [Int] = [],
        observedPhysicalLayerNumbers: [Int] = [],
        missingPhysicalLayerNumbers: [Int] = [],
        expectedCellNames: [String] = [],
        observedCellNames: [String] = [],
        missingCellNames: [String] = [],
        expectedCornerNames: [String] = [],
        observedCornerNames: [String] = [],
        missingCornerNames: [String] = [],
        findings: [PDKValidationFinding] = []
    ) {
        self.isValid = isValid
        self.mappingID = mappingID
        self.expectedLayerNames = expectedLayerNames
        self.observedLayerNames = observedLayerNames
        self.missingLayerNames = missingLayerNames
        self.expectedPhysicalLayerNumbers = expectedPhysicalLayerNumbers
        self.observedPhysicalLayerNumbers = observedPhysicalLayerNumbers
        self.missingPhysicalLayerNumbers = missingPhysicalLayerNumbers
        self.expectedCellNames = expectedCellNames
        self.observedCellNames = observedCellNames
        self.missingCellNames = missingCellNames
        self.expectedCornerNames = expectedCornerNames
        self.observedCornerNames = observedCornerNames
        self.missingCornerNames = missingCornerNames
        self.findings = findings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isValid = try container.decodeIfPresent(Bool.self, forKey: .isValid) ?? false
        mappingID = try container.decodeIfPresent(String.self, forKey: .mappingID)
        expectedLayerNames = try container.decodeIfPresent([String].self, forKey: .expectedLayerNames) ?? []
        observedLayerNames = try container.decodeIfPresent([String].self, forKey: .observedLayerNames) ?? []
        missingLayerNames = try container.decodeIfPresent([String].self, forKey: .missingLayerNames) ?? []
        expectedPhysicalLayerNumbers = try container.decodeIfPresent([Int].self, forKey: .expectedPhysicalLayerNumbers) ?? []
        observedPhysicalLayerNumbers = try container.decodeIfPresent([Int].self, forKey: .observedPhysicalLayerNumbers) ?? []
        missingPhysicalLayerNumbers = try container.decodeIfPresent([Int].self, forKey: .missingPhysicalLayerNumbers) ?? []
        expectedCellNames = try container.decodeIfPresent([String].self, forKey: .expectedCellNames) ?? []
        observedCellNames = try container.decodeIfPresent([String].self, forKey: .observedCellNames) ?? []
        missingCellNames = try container.decodeIfPresent([String].self, forKey: .missingCellNames) ?? []
        expectedCornerNames = try container.decodeIfPresent([String].self, forKey: .expectedCornerNames) ?? []
        observedCornerNames = try container.decodeIfPresent([String].self, forKey: .observedCornerNames) ?? []
        missingCornerNames = try container.decodeIfPresent([String].self, forKey: .missingCornerNames) ?? []
        findings = try container.decodeIfPresent([PDKValidationFinding].self, forKey: .findings) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case isValid
        case mappingID
        case expectedLayerNames
        case observedLayerNames
        case missingLayerNames
        case expectedPhysicalLayerNumbers
        case observedPhysicalLayerNumbers
        case missingPhysicalLayerNumbers
        case expectedCellNames
        case observedCellNames
        case missingCellNames
        case expectedCornerNames
        case observedCornerNames
        case missingCornerNames
        case findings
    }
}
