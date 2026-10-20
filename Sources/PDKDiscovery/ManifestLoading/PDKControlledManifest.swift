import PDKCore

/// Retain this owner, including copies, throughout use of the admitted values.
/// Detached DTO/report/subvalue copies transfer storage responsibility to the caller.
/// This raw-byte result grants no captured-source or artifact authority.
public struct PDKControlledManifest: Sendable {
    private let decoded: PDKDecodedDocument<PDKManifest>
    private let report: PDKDecodedDocument<PDKManifestValidationReport>
    public var manifest: PDKManifest { decoded.value }
    public var validation: PDKManifestValidationReport { report.value }

    internal init(decoded: PDKDecodedDocument<PDKManifest>, report: PDKDecodedDocument<PDKManifestValidationReport>) {
        self.decoded = decoded
        self.report = report
    }
}
