import PDKCore

/// Parses only the checked, fixed-vocabulary schema-1 budget configuration.
public struct NativePDKBudgetBootstrapDecoder: PDKBudgetBootstrapDecoding {
    public init() {}
    public func decode(_ bytes: borrowing Span<UInt8>, policy: PDKBudgetBootstrapPolicy)
        throws(PDKBudgetBootstrapError) -> PDKBudgetBootstrapResult {
        guard UInt64(bytes.count) <= policy.maximumByteCount else { throw .oversizedInput }
        guard !Task.isCancelled else { throw .cancelled }
        var cursor = PDKBudgetBootstrapCursor()
        var fields: UInt8 = 0
        var elapsed: UInt64 = 0
        var limits: [PDKAdmissionResourceDimension: UInt64] = [:]
        limits.reserveCapacity(PDKAdmissionResourceDimension.allCases.count)
        try cursor.expect(123, bytes)
        repeat {
            let name = try cursor.name(bytes)
            let field: UInt8
            if try cursor.matches(name, "schemaVersion") { field = 1 }
            else if try cursor.matches(name, "accountingVersion") { field = 2 }
            else if try cursor.matches(name, "limits") { field = 4 }
            else if try cursor.matches(name, "maximumElapsedNanoseconds") { field = 8 }
            else { throw .unknownField }
            guard fields & field == 0 else { throw .duplicateField }; fields |= field
            try cursor.expect(58, bytes)
            if field == 4 {
                try cursor.expect(91, bytes)
                if !(try cursor.consume(93, bytes)) {
                    repeat {
                        let raw = try cursor.name(bytes)
                        var selected: PDKAdmissionResourceDimension?
                        for dimension in PDKAdmissionResourceDimension.allCases {
                            if try cursor.matches(raw, dimension.rawValue) { selected = dimension; break }
                        }
                        guard let dimension = selected else { throw .unknownDimension }
                        guard limits[dimension] == nil else { throw .duplicateDimension }
                        try cursor.expect(44, bytes)
                        limits[dimension] = try cursor.number(bytes)
                    } while try cursor.consume(44, bytes)
                    try cursor.expect(93, bytes)
                }
            } else {
                let value = try cursor.number(bytes)
                if field == 8 { elapsed = value }
                else { guard value == 1 else { throw .unsupportedVersion } }
            }
        } while try cursor.consume(44, bytes)
        try cursor.expect(125, bytes); try cursor.whitespace(bytes)
        guard cursor.position == bytes.count, fields == 15 else { throw .malformedInput }
        guard limits.count == PDKAdmissionResourceDimension.allCases.count else { throw .incompleteLimits }
        let budget: PDKAdmissionBudget
        do throws(PDKProfileValueError) {
            budget = try .init(limits: limits, maximumElapsedNanoseconds: elapsed)
        } catch { throw .invalidBudget }
        guard !Task.isCancelled else { throw .cancelled }
        return .init(budget: budget, inputByteCount: UInt64(bytes.count), scannedWorkUnitCount: cursor.work,
                     dimensionEntryCapacity: PDKAdmissionResourceDimension.allCases.count)
    }
}
