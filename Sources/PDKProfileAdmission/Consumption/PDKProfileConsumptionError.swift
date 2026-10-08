import PDKCore

public enum PDKProfileConsumptionError: Error, Sendable, Equatable {
    case resource(PDKAdmissionResourceError)
    case value(PDKProfileValueError)
    case invalidStageSubset
    case stageMismatch, profileMismatch, projectionMismatch
    case sourceMismatch(Int), cornerMismatch, selectionMismatch
    case unknownMapping(Int), duplicateMapping(Int), missingMapping(Int)
    case invalidProjection, invalidEvidenceReference
}
