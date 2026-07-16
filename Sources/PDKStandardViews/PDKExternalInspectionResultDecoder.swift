import Foundation
import CircuiteFoundation

public struct PDKExternalInspectionResultDecoder: Sendable {
    public init() {}

    public func decodeStandardView(
        _ data: Data,
        expectedSchemaVersion: Int,
        expectedRunID: String
    ) throws -> PDKStandardViewInspectionResult {
        let result: PDKStandardViewInspectionResult
        do {
            result = try JSONDecoder().decode(
                PDKStandardViewInspectionResult.self,
                from: data
            )
        } catch {
            throw PDKExternalInspectionError.invalidJSON(error.localizedDescription)
        }
        guard result.schemaVersion == expectedSchemaVersion else {
            throw PDKExternalInspectionError.schemaVersionMismatch(
                expected: expectedSchemaVersion,
                actual: result.schemaVersion
            )
        }
        guard result.runID == expectedRunID else {
            throw PDKExternalInspectionError.runIDMismatch(
                expected: expectedRunID,
                actual: result.runID
            )
        }
        return result
    }

    public func decodeRuleDeck(
        _ data: Data,
        expectedSchemaVersion: Int,
        expectedRunID: String
    ) throws -> PDKRuleDeckInspectionResult {
        let result: PDKRuleDeckInspectionResult
        do {
            result = try JSONDecoder().decode(PDKRuleDeckInspectionResult.self, from: data)
        } catch {
            throw PDKExternalInspectionError.invalidJSON(error.localizedDescription)
        }
        guard result.schemaVersion == expectedSchemaVersion else {
            throw PDKExternalInspectionError.schemaVersionMismatch(expected: expectedSchemaVersion, actual: result.schemaVersion)
        }
        guard result.runID == expectedRunID else {
            throw PDKExternalInspectionError.runIDMismatch(expected: expectedRunID, actual: result.runID)
        }
        return result
    }
}
