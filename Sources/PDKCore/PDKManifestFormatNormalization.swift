import Foundation

/// Accounts the manifest DTO's derived format String in the controlled decode context.
internal enum PDKManifestFormatNormalization {
    static func lowercase(_ value: String, decoder: any Decoder) throws -> String {
        guard decoder.userInfo[PDKAdmissionDecodingContext.controlledManifestKey] as? Bool == true,
            let accounting = decoder.userInfo[PDKAdmissionDecodingContext.accountingKey]
            as? any PDKAdmissionResourceAccounting else { return value.lowercased() }
        try accounting.check()
        let count = value.utf8.count
        let (work, overflow) = UInt64(count).addingReportingOverflow(1)
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.parserWork) }
        try accounting.charge(PDKAdmissionCost(dimension: .parserWork, amount: work))
        var index = 0
        for byte in value.utf8 {
            if index & 255 == 0 { try accounting.check() }
            // FIXME(INCOMPLETE_IMPLEMENTATION):
            // Controlled manifest decoding supports ASCII format normalization only.
            // Replace this refusal only after exact Unicode output admission and
            // cooperative cancellation are implemented and behaviorally qualified.
            guard byte < 128 else {
                throw PDKAdmissionResourceError.unsupportedBudgetCapability("Cooperative Unicode manifest format normalization")
            }
            index += 1
        }
        if count > 0 {
            try accounting.charge(PDKAdmissionCost(dimension: .scalarBytes, amount: UInt64(count)))
            _ = try accounting.reserve(PDKAdmissionCost(dimension: .liveOwnedBytes, amount: UInt64(count)))
        }
        // ASCII lowercasing preserves the admitted UTF-8 byte count. The returned
        // immutable backing is retained by the decoded document's reservation owner.
        try accounting.check()
        let normalized = value.lowercased()
        try accounting.check()
        return normalized
    }
}
