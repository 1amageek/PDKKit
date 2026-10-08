public enum PDKResolvedAssetError: Error, Sendable, Equatable {
    case emptyAssetID
    case locatorDescriptorMismatch
    case unsupportedSchemaVersion(Int)
    case obsoleteIdentityField(String)
}
