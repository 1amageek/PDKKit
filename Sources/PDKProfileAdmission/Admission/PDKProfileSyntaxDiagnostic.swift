import CircuiteFoundation
import PDKCore

/// An actual native syntax cause and known physical source location.
public struct PDKProfileSyntaxDiagnostic: Sendable, Equatable {
    public let diagnostic: DesignDiagnostic
    public let sourceKey: String?
    public let file: String?
    public let line: Int?
    public let column: Int?
    private let reservations: PDKAdmissionCollection<PDKAdmissionReservation>

    public init(message: String, sourceKey: String?, file: String?, line: Int?, column: Int?,
                resources: any PDKAdmissionResourceAccounting) throws(PDKProfileInspectionError) {
        let work = PDKAdmissionWork(resources: resources)
        var owners = PDKAdmissionCollection<PDKAdmissionReservation>()
        do throws(PDKProfileAdmissionError) {
            func copy(_ input: String?) throws(PDKProfileAdmissionError) -> String? {
                guard let input else { return nil }
                let count = try work.bytes(input)
                if count > 0 {
                    try work.charge(.diagnosticBytes, count)
                    try owners.append(work.reserve(.liveOwnedBytes, count), work: work)
                    try work.charge(.parserWork, count)
                }
                let result = String(decoding: input.utf8, as: UTF8.self)
                try work.check(); return result
            }
            try work.charge(.diagnosticEntries)
            diagnostic = DesignDiagnostic(code: .trusted("pdk.source.syntax"), severity: .error,
                summary: try copy(message)!)
            self.sourceKey = try copy(sourceKey); self.file = try copy(file)
            self.line = line; self.column = column; self.reservations = owners
            try work.check()
        } catch {
            if case .resource(let cause) = error { throw .resource(cause) }
            throw .invalidFacts
        }
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.diagnostic == rhs.diagnostic && lhs.sourceKey == rhs.sourceKey && lhs.file == rhs.file &&
        lhs.line == rhs.line && lhs.column == rhs.column
    }
}
