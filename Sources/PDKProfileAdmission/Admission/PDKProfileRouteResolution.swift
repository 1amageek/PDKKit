import PDKCore

struct PDKProfileRouteResolution {
    let definition: PDKProfileDefinition
    let work: PDKAdmissionWork
    func child(parentRoute: String, literal: String) throws(PDKProfileAdmissionError) -> (PDKProfileSource, String) {
        guard !literal.isEmpty else { throw .missingDependency }
        var first = true
        var bytes = literal.utf8.makeIterator()
        while true {
            try work.step(); guard let byte = bytes.next() else { break }
            guard byte != 92, !first || (byte != 47 && byte != 126) else { throw .missingDependency }
            first = false
        }
        let parent = try components(parentRoute)
        let parentOwner = parent.1
        defer { withExtendedLifetime(parentOwner) {} }
        if let child = try match(base: parent.0.dropLast(), literal: literal) { return child }
        for search in definition.orderedSearchRoutes {
            try work.step()
            let parts = try components(search)
            let lease = parts.1
            defer { withExtendedLifetime(lease) {} }
            if let child = try match(base: parts.0[...], literal: literal) { return child }
        }
        throw .missingDependency
    }
    private func components(_ route: String) throws(PDKProfileAdmissionError) -> ([Substring], PDKAdmissionReservation?) {
        var count = 1
        for byte in route.utf8 {
            try work.step()
            if byte == 47 {
                let (next, overflow) = count.addingReportingOverflow(1)
                guard !overflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }; count = next
            }
        }
        let owner = try work.capacity(Substring.self, count, dimension: .temporaryBytes)
        try work.charge(.parserWork, try work.bytes(route))
        return (route.split(separator: "/", omittingEmptySubsequences: false), owner)
    }
    private func match(base: ArraySlice<Substring>, literal: String) throws(PDKProfileAdmissionError) -> (PDKProfileSource, String)? {
        let tail = try components(literal)
        let tailOwner = tail.1
        defer { withExtendedLifetime(tailOwner) {} }
        let (capacity, overflow) = base.count.addingReportingOverflow(tail.0.count)
        guard !overflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        let slots = try work.capacity(Substring.self, capacity, dimension: .temporaryBytes)
        defer { withExtendedLifetime(slots) {} }
        var normalized: [Substring] = []; normalized.reserveCapacity(capacity)
        for part in base { try work.step(); normalized.append(part) }
        for part in tail.0 {
            try work.step()
            let dots = try dotSegment(part)
            if dots == 1 { continue }
            if dots == 2 { guard !normalized.isEmpty else { throw .missingDependency }; normalized.removeLast() }
            else { guard !part.isEmpty else { throw .missingDependency }; normalized.append(part) }
        }
        var byteCount: UInt64 = 0
        for part in normalized {
            for _ in part.utf8 { try work.step(); let (next, overflow) = byteCount.addingReportingOverflow(1)
                guard !overflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }; byteCount = next }
        }
        let (total, separatorOverflow) = byteCount.addingReportingOverflow(UInt64(Swift.max(0, normalized.count - 1)))
        guard !separatorOverflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        let textOwner = total == 0 ? nil : try work.reserve(.temporaryBytes, total)
        defer { withExtendedLifetime(textOwner) {} }
        try work.charge(.parserWork, total)
        let route = normalized.joined(separator: "/")
        var selected: (PDKProfileSource, String)?
        for source in definition.sources {
            try work.step()
            for declared in source.logicalRoutes {
                if try work.equal(route, declared) {
                    if let selected, try !work.equal(selected.0.sourceKey, source.sourceKey) { throw .ambiguousDependency }
                    selected = (source, declared)
                }
            }
        }
        return selected
    }
    private func dotSegment(_ part: Substring) throws(PDKProfileAdmissionError) -> Int {
        var iterator = part.utf8.makeIterator()
        try work.step(); guard iterator.next() == 46 else { return 0 }
        try work.step(); guard let second = iterator.next() else { return 1 }
        guard second == 46 else { return 0 }
        try work.step(); return iterator.next() == nil ? 2 : 0
    }
}
