import Foundation
import PDKCore
import PDKStandardViews
import XcircuitePackage

public struct PDKRuleDeckValidationResult: Sendable, Hashable, Codable {
    public var assetID: String
    public var status: XcircuiteEngineExecutionStatus
    public var isValid: Bool
    public var reference: XcircuiteFileReference?
    public var expectedLayerIDs: [String]
    public var observedLayerIDs: [String]
    public var statementCount: Int
    public var inspection: PDKRuleDeckInspectionPayload?
    public var findings: [PDKValidationFinding]

    public init(
        assetID: String,
        status: XcircuiteEngineExecutionStatus,
        isValid: Bool,
        reference: XcircuiteFileReference? = nil,
        expectedLayerIDs: [String] = [],
        observedLayerIDs: [String] = [],
        statementCount: Int = 0,
        inspection: PDKRuleDeckInspectionPayload? = nil,
        findings: [PDKValidationFinding] = []
    ) {
        self.assetID = assetID
        self.status = status
        self.isValid = isValid
        self.reference = reference
        self.expectedLayerIDs = expectedLayerIDs
        self.observedLayerIDs = observedLayerIDs
        self.statementCount = statementCount
        self.inspection = inspection
        self.findings = findings
    }
}
