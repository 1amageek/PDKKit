import PDKCore

/// Exclusive synchronous encoding state; trusted witnesses must not retain its Encoder.
internal final class PDKJSONEncodingContext {
    let resources: any PDKAdmissionResourceAccounting
    var failure: PDKProfileOutputError?
    private var temporaries: [PDKAdmissionReservation] = []
    init(resources: any PDKAdmissionResourceAccounting) { self.resources = resources }

    func check() throws {
        if let failure { throw failure }
        do { try resources.check() }
        catch { failure = .resource(error); throw error }
    }
    func reserve(_ dimension: PDKAdmissionResourceDimension, _ count: Int) throws -> PDKAdmissionReservation? {
        try check()
        guard count >= 0 else { throw PDKProfileOutputError.capacityOverflow }
        guard count > 0 else { return nil }
        do { return try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: UInt64(count))) }
        catch { failure = .resource(error); throw error }
    }
    func work(_ count: Int = 1) throws { _ = try reserve(.parserWork, count) }
    func temporary(_ count: Int) throws {
        if let receipt = try reserve(.temporaryBytes, count) { temporaries.append(receipt) }
    }
    func bytes<Element>(for type: Element.Type, count: Int) throws -> Int {
        let (size, overflow) = MemoryLayout<Element>.stride.multipliedReportingOverflow(by: count)
        guard !overflow else { throw PDKProfileOutputError.capacityOverflow }
        return size
    }
    func record(_ operation: () throws -> Void) {
        guard failure == nil else { return }
        do { try operation() } catch { failure = .preserving(error) }
    }
}
