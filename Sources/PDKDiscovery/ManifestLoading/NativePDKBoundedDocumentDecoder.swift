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

    /// Decode storage is accounted; the specializing owner must audit/account custom
    /// Decodable, CodingKey and validation-hook allocations and work separately.
    /// Retain the returned handle while using its value. This is not an arbitrary
    /// generic whole-invocation allocation guarantee.
    public func decodeAudited<Value: Decodable & Sendable>(_ type: Value.Type, source: CapturedPDKSource,
        accounting: any PDKAdmissionResourceAccounting, rejectUnknownFields: Bool,
        validate: (any Decoder) throws -> Void) throws(PDKBoundedDecodeError) -> PDKDecodedDocument<Value> {
        try decode(type, source: source, accounting: accounting, rejectUnknownFields: rejectUnknownFields, validate: validate)
    }

    /// Decodes caller-owned bytes without granting source or artifact authority.
    /// The caller keeps the byte owner alive for this synchronous borrow. Custom
    /// Decodable/CodingKey/hooks must admit their additional payload and work.
    public func decodeAudited<Value: Decodable & Sendable>(_ type: Value.Type, bytes: borrowing Span<UInt8>,
        accounting: any PDKAdmissionResourceAccounting, rejectUnknownFields: Bool,
        validate: (any Decoder) throws -> Void) throws(PDKControlledDecodeFailure) -> PDKDecodedDocument<Value> {
        let resources = try prepareControlledDecoding(accounting)
        do {
            return try decode(type, bytes: bytes, accounting: accounting, rejectUnknownFields: rejectUnknownFields,
                validate: validate, retention: resources)
        } catch {
            // Transfer existing receipts only: no admission/cancellation callback
            // may be needed to preserve an already-materialized failure payload.
            throw PDKControlledDecodeFailure(cause: error, reservations: resources.takeOwned())
        }
    }

    internal func prepareControlledDecoding(_ accounting: any PDKAdmissionResourceAccounting)
        throws(PDKControlledDecodeFailure) -> PDKDecodeResourceAccounting {
        let resources = PDKDecodeResourceAccounting(accounting)
        do {
            try resources.capacity(1, stride: MemoryLayout<PDKControlledDecodeFailure>.stride, dimension: .liveOwnedBytes)
            try resources.check()
            return resources
        } catch let error as PDKAdmissionResourceError {
            // Before parsing there is no PDK-owned decoded input payload. The
            // trusted accountant owns its already-materialized error backing;
            // preserve that original typed cause without a new payload copy.
            throw PDKControlledDecodeFailure(cause: .resource(error), reservations: resources.takeOwned())
        } catch {
            throw PDKControlledDecodeFailure(cause: .unsupportedValue("Controlled decode failure metadata"),
                reservations: resources.takeOwned())
        }
    }

    private func decode<T: Decodable & Sendable>(_ type: T.Type, source: CapturedPDKSource,
        accounting: any PDKAdmissionResourceAccounting, rejectUnknownFields: Bool = false,
        validate: (any Decoder) throws -> Void = { _ in }) throws(PDKBoundedDecodeError) -> PDKDecodedDocument<T> {
        do {
            let decoded = try source.withBytes { bytes in
                try decode(type, bytes: bytes, accounting: accounting, rejectUnknownFields: rejectUnknownFields, validate: validate)
            }
            let bound = decoded.binding(to: source.reference)
            try accounting.check()
            return bound
        }
        catch let error as PDKAdmissionResourceError { throw .resource(error) }
        catch let error as PDKBoundedDecodeError { throw error }
        catch { throw .unsupportedValue("Captured byte access") }
    }

    internal func decode<T: Decodable & Sendable>(_ type: T.Type, bytes: borrowing Span<UInt8>,
        accounting: any PDKAdmissionResourceAccounting, rejectUnknownFields: Bool = false,
        validate: (any Decoder) throws -> Void = { _ in },
        controlledManifest: Bool = false, retention: PDKDecodeResourceAccounting? = nil,
        transferOwned: Bool = true) throws(PDKBoundedDecodeError) -> PDKDecodedDocument<T> {
        do {
            let resources = retention ?? PDKDecodeResourceAccounting(accounting)
            let document = try bytes.withUnsafeBufferPointer { pointer in
                var parser = PDKJSONSyntaxParser(bytes: pointer, resources: resources)
                return try parser.parse()
            }
            try resources.dictionaryCapacity(controlledManifest ? 2 : 1, keyStride: MemoryLayout<CodingUserInfoKey>.stride,
                valueStride: MemoryLayout<Any>.stride, growing: false, dimension: .temporaryBytes)
            var userInfo: [CodingUserInfoKey: Any] = [PDKAdmissionDecodingContext.accountingKey: resources]
            if controlledManifest { userInfo[PDKAdmissionDecodingContext.controlledManifestKey] = true }
            let decoder = PDKJSONValueDecoder(document: document, node: document.root, resources: resources, codingPath: [],
                userInfo: userInfo, rejectUnknownFields: rejectUnknownFields)
            try resources.capacity(1, stride: MemoryLayout<PDKDecodedDocument<T>>.stride, dimension: .liveOwnedBytes)
            try validate(decoder)
            let value = try decoder.decode(type)
            try resources.check()
            return PDKDecodedDocument(value: value, reservations: transferOwned ? resources.takeOwned() : [])
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
