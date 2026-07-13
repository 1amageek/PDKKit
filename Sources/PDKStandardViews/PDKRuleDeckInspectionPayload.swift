import Foundation
import PDKCore
import XcircuitePackage

public struct PDKRuleDeckInspectionPayload: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var assetID: String
    public var pdkDigest: String
    public var reference: XcircuiteFileReference?
    public var statementCount: Int
    public var expectedLayerIDs: [String]
    public var observedLayerIDs: [String]
    public var layerEvidence: [PDKRuleDeckLayerEvidence]
    public var findings: [PDKValidationFinding]
    public var limitations: [String]

    public init(
        isValid: Bool,
        assetID: String,
        pdkDigest: String,
        reference: XcircuiteFileReference? = nil,
        statementCount: Int = 0,
        expectedLayerIDs: [String] = [],
        observedLayerIDs: [String] = [],
        layerEvidence: [PDKRuleDeckLayerEvidence] = [],
        findings: [PDKValidationFinding] = [],
        limitations: [String] = []
    ) {
        self.isValid = isValid
        self.assetID = assetID
        self.pdkDigest = pdkDigest
        self.reference = reference
        self.statementCount = statementCount
        self.expectedLayerIDs = expectedLayerIDs
        self.observedLayerIDs = observedLayerIDs
        self.layerEvidence = layerEvidence
        self.findings = findings
        self.limitations = limitations
    }
}
