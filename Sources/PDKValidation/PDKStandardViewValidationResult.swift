import Foundation
import PDKCore
import PDKStandardViews
import CircuiteFoundation

public struct PDKStandardViewValidationResult: Sendable, Hashable, Codable {
    public var assetID: String
    public var format: PDKStandardViewFormat
    public var status: PDKExecutionStatus
    public var payload: PDKManifestViewInspectionPayload

    public init(
        assetID: String,
        format: PDKStandardViewFormat,
        status: PDKExecutionStatus,
        payload: PDKManifestViewInspectionPayload
    ) {
        self.assetID = assetID
        self.format = format
        self.status = status
        self.payload = payload
    }
}
