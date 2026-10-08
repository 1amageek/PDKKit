import Foundation

/// Wire coding is a structural boundary; callers must separately account decode work and storage.
public protocol PDKProfileCoding: Sendable {
    func decodeDefinition(_ data: Data) throws(PDKProfileValueError) -> PDKProfileDefinition
    func decodeClaim(_ data: Data) throws(PDKProfileValueError) -> PDKProfileClaim
    func encodeDefinition(_ value: PDKProfileDefinition) throws(PDKProfileValueError) -> Data
    func encodeClaim(_ value: PDKProfileClaim) throws(PDKProfileValueError) -> Data
}
