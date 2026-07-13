import Foundation
import XcircuitePackage

public struct PDKExternalInspectionEnvelopeDecoder: Sendable {
    public init() {}

    public func decode<Payload: Sendable & Hashable & Codable>(
        _ data: Data,
        payload: Payload.Type,
        expectedSchemaVersion: Int,
        expectedRunID: String
    ) throws -> XcircuiteEngineResultEnvelope<Payload> {
        let envelope: XcircuiteEngineResultEnvelope<Payload>
        do {
            envelope = try JSONDecoder().decode(
                XcircuiteEngineResultEnvelope<Payload>.self,
                from: data
            )
        } catch {
            throw PDKExternalInspectionError.invalidJSON(error.localizedDescription)
        }
        guard envelope.schemaVersion == expectedSchemaVersion else {
            throw PDKExternalInspectionError.schemaVersionMismatch(
                expected: expectedSchemaVersion,
                actual: envelope.schemaVersion
            )
        }
        guard envelope.runID == expectedRunID else {
            throw PDKExternalInspectionError.runIDMismatch(
                expected: expectedRunID,
                actual: envelope.runID
            )
        }
        return envelope
    }
}
