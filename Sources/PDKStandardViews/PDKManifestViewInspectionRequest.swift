import Foundation
import PDKCore
import XcircuitePackage

public struct PDKManifestViewInspectionRequest: XcircuiteEngineRequest {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [XcircuiteFileReference]
    public var pdk: PDKReference
    public var assetID: String
    public var format: PDKStandardViewFormat
    public var requireNonEmpty: Bool

    public init(
        runID: String,
        inputs: [XcircuiteFileReference],
        pdk: PDKReference,
        assetID: String,
        format: PDKStandardViewFormat,
        requireNonEmpty: Bool = true
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = inputs
        self.pdk = pdk
        self.assetID = assetID
        self.format = format
        self.requireNonEmpty = requireNonEmpty
    }
}
