import Foundation

public protocol PDKDigesting: Sendable {
    func digest(data: Data) throws -> String
}
