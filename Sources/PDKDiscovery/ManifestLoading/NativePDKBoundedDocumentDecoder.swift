import Foundation
import PDKCore
import PDKSourceCapture

public struct NativePDKBoundedDocumentDecoder: PDKBoundedDocumentDecoding {
    public init() {}

    public func decodeManifest(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKManifest> {
        try decode(PDKManifest.self, source: source, accounting: accounting)
    }
    public func decodeDefinition(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKProfileDefinition> {
        try decode(PDKProfileDefinition.self, source: source, accounting: accounting)
    }
    public func decodeClaim(_ source: CapturedPDKSource, accounting: any PDKAdmissionResourceAccounting)
        throws(PDKBoundedDecodeError) -> PDKDecodedDocument<PDKProfileClaim> {
        try decode(PDKProfileClaim.self, source: source, accounting: accounting)
    }

    private func decode<T: Decodable & Sendable>(_ type: T.Type, source: CapturedPDKSource,
        accounting: any PDKAdmissionResourceAccounting) throws(PDKBoundedDecodeError) -> PDKDecodedDocument<T> {
        do {
            let decoded = try source.withBytes { bytes in try decode(type, bytes: bytes, accounting: accounting) }
            let bound = decoded.binding(to: source.reference)
            try accounting.check()
            return bound
        }
        catch let error as PDKAdmissionResourceError { throw .resource(error) }
        catch let error as PDKBoundedDecodeError { throw error }
        catch { throw .unsupportedValue("Captured byte access") }
    }

    internal func decode<T: Decodable & Sendable>(_ type: T.Type, bytes: borrowing Span<UInt8>,
        accounting: any PDKAdmissionResourceAccounting) throws(PDKBoundedDecodeError) -> PDKDecodedDocument<T> {
        do {
            let resources = PDKDecodeResourceAccounting(accounting)
            let document = try bytes.withUnsafeBufferPointer { pointer in
                var parser = PDKJSONSyntaxParser(bytes: pointer, resources: resources)
                return try parser.parse()
            }
            try resources.dictionaryCapacity(1, keyStride: MemoryLayout<CodingUserInfoKey>.stride,
                valueStride: MemoryLayout<Any>.stride, growing: false, dimension: .temporaryBytes)
            let decoder = PDKJSONValueDecoder(document: document, node: document.root, resources: resources, codingPath: [],
                userInfo: [PDKAdmissionDecodingContext.accountingKey: resources])
            try resources.capacity(1, stride: MemoryLayout<PDKDecodedDocument<T>>.stride, dimension: .liveOwnedBytes)
            let value = try decoder.decode(type)
            try resources.check()
            return PDKDecodedDocument(value: value, reservations: resources.takeOwned())
        } catch let error as PDKAdmissionResourceError { throw .resource(error) }
        catch let error as PDKBoundedDecodeError { throw error }
        catch let error as PDKManifestError { throw .manifest(error) }
        catch let error as PDKProfileValueError {
            if case .resource(let resource) = error { throw .resource(resource) }
            throw .profile(error)
        }
        catch { throw .unsupportedValue("Document violates its checked Codable contract") }
    }
}
