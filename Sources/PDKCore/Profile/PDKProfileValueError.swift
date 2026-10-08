public enum PDKProfileValueError: Error, Sendable, Equatable {
    case resource(PDKAdmissionResourceError)
    case invalidID(String)
    case duplicateKey(String)
    case unsupportedSchema(Int)
    case invalidPVT(String)
    case invalidRoute(String)
    case missingSelection(String)
    case ambiguousSelection(String)
    case conflictingReference(String)
    case noncanonicalEncoding(String)
    case invalidBudget(String)
}
