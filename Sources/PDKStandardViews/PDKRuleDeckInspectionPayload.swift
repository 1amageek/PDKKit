import Foundation
import CircuiteFoundation
import PDKCore
import CircuiteFoundation

public struct PDKRuleDeckInspectionPayload: Sendable, Hashable, Codable {
    public var isValid: Bool
    public var assetID: String
    public var pdkDigest: String
    public var reference: ArtifactLocator?
    public var sourceArtifact: ArtifactReference?
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
        reference: ArtifactLocator? = nil,
        sourceArtifact: ArtifactReference? = nil,
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
        self.sourceArtifact = sourceArtifact
        self.statementCount = statementCount
        self.expectedLayerIDs = expectedLayerIDs
        self.observedLayerIDs = observedLayerIDs
        self.layerEvidence = layerEvidence
        self.findings = findings
        self.limitations = limitations
    }
}
