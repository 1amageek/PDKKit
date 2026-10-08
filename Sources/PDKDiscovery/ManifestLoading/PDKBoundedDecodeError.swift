import PDKCore

public enum PDKBoundedDecodeError: Error, Sendable, Equatable {
    case resource(PDKAdmissionResourceError)
    case malformed(byteOffset: Int, reason: String)
    case duplicateKey(byteOffset: Int)
    case invalidUTF8(byteOffset: Int)
    case invalidNumber
    case typeMismatch(expected: String)
    case missingKey(String)
    case manifest(PDKManifestError)
    case profile(PDKProfileValueError)
    case unsupportedValue(String)
}
