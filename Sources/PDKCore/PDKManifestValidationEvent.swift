/// Package-only construction seam for the single manifest rule implementation.
package enum PDKManifestValidationEvent {
    case checkpoint
    case work(Int)
    case inspect(String)
    case projection(Int)
    case identifierSet(Int)
    case findingGrowth(Int)
    case findingActions
    case diagnostic(PDKValidationFinding)
    case temporaryText(Int)
    case retainedText(Int)
    case joinedEntity(Int, Int)
}
