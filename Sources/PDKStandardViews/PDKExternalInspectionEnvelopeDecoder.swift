import Foundation
import CircuiteFoundation

public struct PDKExternalInspectionEnvelopeDecoder: Sendable {
    public init() {}

    public func decodeStandardView(
        _ data: Data,
        expectedSchemaVersion: Int,
        expectedRunID: String
    ) throws -> PDKStandardViewInspectionResult {
        let envelope: PDKStandardViewInspectionResult
        do {
            envelope = try JSONDecoder().decode(
                PDKStandardViewInspectionResult.self,
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

    public func decodeRuleDeck(
        _ data: Data,
        expectedSchemaVersion: Int,
        expectedRunID: String
    ) throws -> PDKRuleDeckInspectionResult {
        let envelope: PDKRuleDeckInspectionResult
        do {
            envelope = try JSONDecoder().decode(PDKRuleDeckInspectionResult.self, from: data)
        } catch {
            throw PDKExternalInspectionError.invalidJSON(error.localizedDescription)
        }
        guard envelope.schemaVersion == expectedSchemaVersion else {
            throw PDKExternalInspectionError.schemaVersionMismatch(expected: expectedSchemaVersion, actual: envelope.schemaVersion)
        }
        guard envelope.runID == expectedRunID else {
            throw PDKExternalInspectionError.runIDMismatch(expected: expectedRunID, actual: envelope.runID)
        }
        return envelope
    }
}
