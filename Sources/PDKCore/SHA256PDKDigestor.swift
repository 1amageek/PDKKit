import CryptoKit
import Foundation

public struct SHA256PDKDigestor: PDKDigesting {
    public init() {}

    public func digest(data: Data) throws -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
