public enum PDKBudgetBootstrapError: Error, Sendable, Equatable {
    case invalidPolicy
    case oversizedInput
    case malformedInput
    case unknownField
    case duplicateField
    case unknownDimension
    case duplicateDimension
    case incompleteLimits
    case unsupportedVersion
    case invalidBudget
    case arithmeticOverflow
    case cancelled
}
