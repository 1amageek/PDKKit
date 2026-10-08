import CoreSpiceIO
import PDKCore

/// Availability routing follows exact admission precedence; it never probes a filesystem.
struct PDKSpiceCandidateRoutes {
    let request: PDKSpiceCandidateDiscoveryRequest
    let bridge: PDKSpiceResourceBridge

    func match(_ route: String) throws -> Int? {
        var selected: Int?
        for index in request.sources.indices {
            for candidate in request.sources[index].logicalRoutes {
                if try bridge.equal(candidate, route) {
                    if let selected, try !bridge.equal(request.sources[selected].sourceKey, request.sources[index].sourceKey) {
                        throw PDKSpiceCandidateDiscoveryError.ambiguousRoute
                    }
                    if selected == nil { selected = index }
                }
            }
        }
        return selected
    }
    func child(parentRoute: String, literal: String) throws -> (Int, SPICEAccountedText) {
        try validateLiteral(literal)
        let parent = try parts(parentRoute)
        defer { withExtendedLifetime(parent.owner) {} }
        let relative = try normalized(base: parent.values.dropLast(), literal: literal)
        if let binding = try match(relative.text) { return (binding, relative) }
        for search in request.orderedSearchRoutes {
            let base = try parts(search)
            defer { withExtendedLifetime(base.owner) {} }
            let route = try normalized(base: base.values[...], literal: literal)
            if let binding = try match(route.text) { return (binding, route) }
        }
        throw PDKSpiceCandidateDiscoveryError.missingRoute
    }
    func validateCanonical(_ route: String) throws {
        try validateLiteral(route)
        let value = try normalized(base: [], literal: route)
        guard try bridge.equal(value.text, route) else { throw PDKSpiceCandidateDiscoveryError.invalidRequest }
    }
    private func validateLiteral(_ literal: String) throws {
        guard !literal.isEmpty else { throw PDKSpiceCandidateDiscoveryError.missingRoute }
        var first = true
        for byte in literal.utf8 {
            try bridge.charge(.lexicalBytes, units: 1)
            guard byte != 0, byte != 92, !first || (byte != 47 && byte != 126) else {
                throw PDKSpiceCandidateDiscoveryError.escapingRoute
            }
            first = false
        }
    }
    private func parts(_ route: String) throws -> (values: [Substring], owner: SPICESourceStorageReservation) {
        var count = 1
        for byte in route.utf8 {
            try bridge.charge(.lexicalBytes, units: 1)
            guard byte < 128 else {
                throw PDKAdmissionResourceError.unsupportedBudgetCapability("Cooperative Unicode candidate routing")
            }
            if byte == 47 {
                let (next, overflow) = count.addingReportingOverflow(1)
                guard !overflow else { throw SPICESourceStorageError.arithmeticOverflow }; count = next
            }
        }
        let owner = try SPICESourceCapacity.reserve(of: Substring.self, capacity: count,
            kind: .temporaryBytes, resources: bridge)
        var values: [Substring] = []; values.reserveCapacity(count)
        var start = route.startIndex, cursor = start
        while cursor < route.endIndex {
            try bridge.charge(.lexicalBytes, units: 1)
            let next = route.index(after: cursor)
            if route[cursor] == "/" { values.append(route[start..<cursor]); start = next }
            cursor = next
        }
        values.append(route[start..<cursor])
        return (values, owner)
    }
    private func normalized(base: ArraySlice<Substring>, literal: String) throws -> SPICEAccountedText {
        let tail = try parts(literal)
        defer { withExtendedLifetime(tail.owner) {} }
        let (capacity, overflow) = base.count.addingReportingOverflow(tail.values.count)
        guard !overflow else { throw SPICESourceStorageError.arithmeticOverflow }
        let slotOwner = try SPICESourceCapacity.reserve(of: Substring.self, capacity: capacity,
            kind: .temporaryBytes, resources: bridge)
        defer { withExtendedLifetime(slotOwner) {} }
        var segments: [Substring] = []; segments.reserveCapacity(capacity)
        for segment in base { try bridge.charge(.tokens, units: 1); segments.append(segment) }
        for segment in tail.values {
            try bridge.charge(.tokens, units: 1)
            if segment == "." { continue }
            if segment == ".." {
                guard !segments.isEmpty else { throw PDKSpiceCandidateDiscoveryError.escapingRoute }
                segments.removeLast()
            } else {
                guard !segment.isEmpty else { throw PDKSpiceCandidateDiscoveryError.invalidRequest }
                segments.append(segment)
            }
        }
        guard !segments.isEmpty else { throw PDKSpiceCandidateDiscoveryError.missingRoute }
        var count = segments.count - 1
        for segment in segments {
            for _ in segment.utf8 {
                try bridge.charge(.lexicalBytes, units: 1)
                let (next, overflow) = count.addingReportingOverflow(1)
                guard !overflow else { throw SPICESourceStorageError.arithmeticOverflow }; count = next
            }
        }
        let bufferOwner = try bridge.reserveStorage(kind: .temporaryBytes, byteCount: UInt64(count))
        defer { withExtendedLifetime(bufferOwner) {} }
        var bytes: [UInt8] = []; bytes.reserveCapacity(count)
        for (index, segment) in segments.enumerated() {
            if index > 0 { bytes.append(47) }
            for byte in segment.utf8 { try bridge.charge(.projectedBytes, units: 1); bytes.append(byte) }
        }
        return try SPICEAccountedText.admit(bytes: bytes.span, resources: bridge, maximumChunkByteCount: 256)
    }
}
