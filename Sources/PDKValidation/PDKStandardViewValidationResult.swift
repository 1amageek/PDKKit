import Foundation
import PDKStandardViews
import XcircuitePackage

public struct PDKStandardViewValidationResult: Sendable, Hashable, Codable {
    public var assetID: String
    public var format: PDKStandardViewFormat
    public var status: XcircuiteEngineExecutionStatus
    public var payload: PDKManifestViewInspectionPayload

    public init(
        assetID: String,
        format: PDKStandardViewFormat,
        status: XcircuiteEngineExecutionStatus,
        payload: PDKManifestViewInspectionPayload
    ) {
        self.assetID = assetID
        self.format = format
        self.status = status
        self.payload = payload
    }
}
