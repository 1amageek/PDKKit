import PDKCore

extension NativePDKBoundedDocumentDecoder: PDKControlledManifestDecoding {
    public func decodeAndValidateManifest(bytes: borrowing Span<UInt8>,
        accounting: any PDKAdmissionResourceAccounting) throws(PDKControlledDecodeFailure) -> PDKControlledManifest {
        let resources = try prepareControlledDecoding(accounting)
        do {
            // Keep all owned receipts in this one scope through validation. No
            // naked DTO can outlive its accounting if a later operation fails.
            let decoded = try decode(PDKManifest.self, bytes: bytes, accounting: accounting,
                rejectUnknownFields: false, validate: { _ in }, controlledManifest: true,
                retention: resources, transferOwned: false)
            let construction = PDKManifestValidationAccounting(resources: resources)
            try resources.capacity(1, stride: MemoryLayout<PDKControlledManifest>.stride, dimension: .liveOwnedBytes)
            try resources.capacity(1, stride: MemoryLayout<PDKDecodedDocument<PDKManifestValidationReport>>.stride,
                dimension: .liveOwnedBytes)
            let report = try PDKManifestValidator().validate(decoded.value, construction: construction.admit)
            try resources.check()
            try accounting.check()
            // After the final control check, ownership transfer performs no new
            // admission/check callback. The report owner retains both phases.
            let retained = PDKDecodedDocument(value: report, reservations: resources.takeOwned())
            return PDKControlledManifest(decoded: decoded, report: retained)
        } catch let error as PDKAdmissionResourceError {
            throw PDKControlledDecodeFailure(cause: .resource(error), reservations: resources.takeOwned())
        } catch let error as PDKBoundedDecodeError {
            throw PDKControlledDecodeFailure(cause: error, reservations: resources.takeOwned())
        } catch {
            throw PDKControlledDecodeFailure(cause: .unsupportedValue("Controlled manifest validation construction"),
                reservations: resources.takeOwned())
        }
    }
}
