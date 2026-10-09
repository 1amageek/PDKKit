import PDKCore

public enum PDKProfileConsumptionError: Error, Sendable, Equatable {
    case resource(PDKAdmissionResourceError)
    case value(PDKProfileValueError)
    case invalidStageSubset
    case stageMismatch, profileMismatch, projectionMismatch
    case sourceMismatch(Int), cornerMismatch, selectionMismatch
    case unknownMapping(Int), duplicateMapping(Int), missingMapping(Int)
    case executionInputMismatch, executionConfigurationMismatch
    case executionBindingMismatch(Int), executionEntryMismatch(Int), executionContextMismatch(Int)
    case unknownExecutionOccurrence(UInt64), unrepresentedExecutionContributor(Int)
    case invalidProjection, invalidEvidenceReference
}
