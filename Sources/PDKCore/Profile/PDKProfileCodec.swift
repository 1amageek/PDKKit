import Foundation

public struct PDKProfileCodec: PDKProfileCoding {
    public init() {}
    public func decodeDefinition(_ data: Data) throws(PDKProfileValueError) -> PDKProfileDefinition { try decode(data) }
    public func decodeClaim(_ data: Data) throws(PDKProfileValueError) -> PDKProfileClaim { try decode(data) }
    public func encodeDefinition(_ value: PDKProfileDefinition) throws(PDKProfileValueError) -> Data { try encode(value) }
    public func encodeClaim(_ value: PDKProfileClaim) throws(PDKProfileValueError) -> Data { try encode(value) }
    private func decode<T: Decodable>(_ data: Data) throws(PDKProfileValueError) -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch let error as PDKProfileValueError { throw error }
        catch { throw .noncanonicalEncoding(String(describing: error)) }
    }
    private func encode<T: Encodable>(_ value: T) throws(PDKProfileValueError) -> Data {
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(value)
        } catch let error as PDKProfileValueError { throw error }
        catch { throw .noncanonicalEncoding(String(describing: error)) }
    }
}
