import PDKCore
import PDKProfileAdmission

/// The fixed native suffix schema. Bootstrap accounting remains separate from admission.
public struct PDKProfileOutputObservations: Sendable {
    public let snapshot: PDKAdmissionResourceSnapshot
    public let bootstrap: PDKBudgetBootstrapResult
    public let elapsedNanoseconds: UInt64

    public init(snapshot: PDKAdmissionResourceSnapshot, bootstrap: PDKBudgetBootstrapResult)
        throws(PDKProfileOutputError) {
        let components = snapshot.elapsed.components
        guard components.seconds >= 0, components.attoseconds >= 0 else { throw .elapsedOverflow }
        let (seconds, overflow) = UInt64(components.seconds).multipliedReportingOverflow(by: 1_000_000_000)
        let (elapsed, additionOverflow) = seconds.addingReportingOverflow(UInt64(components.attoseconds / 1_000_000_000))
        guard !overflow, !additionOverflow else { throw .elapsedOverflow }
        self.snapshot = snapshot; self.bootstrap = bootstrap; self.elapsedNanoseconds = elapsed
    }

    /// Includes the envelope field prefix, worst-case numeric widths, final brace and newline.
    public static var maximumSuffixByteCount: Int {
        var size = ",\"operationalObservations\":{\"boundary\":\"prepared-output\",\"admission\":{\"accountingVersion\":".utf8.count + 20
        size += ",\"elapsedNanoseconds\":".utf8.count + 20
        size += ",\"maximumElapsedNanoseconds\":".utf8.count + 20
        size += ",\"isClosed\":false,\"isDeadlineExceeded\":false,\"dimensions\":[".utf8.count
        for (index, dimension) in PDKAdmissionResourceDimension.allCases.enumerated() {
            if index > 0 { size += 1 }
            size += "{\"dimension\":\"\",\"limit\":".utf8.count + dimension.rawValue.utf8.count + 20
            if dimension.isLiveCapacity { size += ",\"current\":,\"peak\":".utf8.count + 40 }
            else { size += ",\"total\":".utf8.count + 20 }
            size += 1
        }
        size += "]},\"bootstrap\":{\"inputByteCount\":,\"scannedWorkUnitCount\":,\"dimensionEntryCapacity\":}}}\n".utf8.count + 60
        return size
    }

    internal func write(hasPayloadFields: Bool, append: (UInt8) throws -> Void) throws {
        func text(_ value: String) throws { for byte in value.utf8 { try append(byte) } }
        func number(_ value: UInt64) throws { try text(String(value)) }
        if hasPayloadFields { try append(44) }
        try text("\"operationalObservations\":{\"boundary\":\"prepared-output\",\"admission\":{\"accountingVersion\":")
        try number(UInt64(snapshot.accountingVersion))
        try text(",\"elapsedNanoseconds\":"); try number(elapsedNanoseconds)
        try text(",\"maximumElapsedNanoseconds\":"); try number(snapshot.maximumElapsedNanoseconds)
        try text(",\"isClosed\":"); try text(snapshot.isClosed ? "true" : "false")
        try text(",\"isDeadlineExceeded\":"); try text(snapshot.isDeadlineExceeded ? "true" : "false")
        try text(",\"dimensions\":[")
        for (index, entry) in snapshot.dimensions.enumerated() {
            if index > 0 { try append(44) }
            try text("{\"dimension\":\""); try text(entry.dimension.rawValue)
            try text("\",\"limit\":"); try number(entry.limit)
            switch entry.usage {
            case .cumulative(let total): try text(",\"total\":"); try number(total)
            case .live(let current, let peak):
                try text(",\"current\":"); try number(current)
                try text(",\"peak\":"); try number(peak)
            }
            try append(125)
        }
        try text("]},\"bootstrap\":{\"inputByteCount\":"); try number(bootstrap.inputByteCount)
        try text(",\"scannedWorkUnitCount\":"); try number(bootstrap.scannedWorkUnitCount)
        try text(",\"dimensionEntryCapacity\":"); try number(UInt64(bootstrap.dimensionEntryCapacity))
        try text("}}}\n")
    }
}
