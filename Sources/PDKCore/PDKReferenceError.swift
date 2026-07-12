import Foundation

public enum PDKReferenceError: Error, Sendable, Equatable {
    case emptyProcessID
    case emptyVersion
    case emptyDigest
    case malformedDigest
    case manifestDigestMismatch(expected: String, actual: String)
}
