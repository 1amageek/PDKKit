import CircuiteFoundation
import CircuiteFoundationFoundation

/// Local synchronous construction scope; this mutable helper never crosses an isolation boundary.
final class PDKProfileConstructionWork {
    let resources: (any PDKAdmissionResourceAccounting)?
    private var temporaryReservations: [PDKAdmissionReservation] = []
    init(_ resources: (any PDKAdmissionResourceAccounting)?) { self.resources = resources }

    func check() throws(PDKProfileValueError) {
        do { try resources?.check() } catch { throw .resource(error) }
    }
    func step(_ amount: UInt64 = 1) throws(PDKProfileValueError) {
        try charge(.parserWork, amount)
    }
    func charge(_ dimension: PDKAdmissionResourceDimension, _ amount: UInt64) throws(PDKProfileValueError) {
        try check()
        guard let resources, amount > 0 else { return }
        do { try resources.charge(PDKAdmissionCost(dimension: dimension, amount: amount)) }
        catch { throw .resource(error) }
    }
    func retained<T>(_ type: T.Type, capacity: Int) throws(PDKProfileValueError) -> PDKAdmissionReservation? {
        try capacityReservation(type, capacity: capacity, dimension: .liveOwnedBytes)
    }
    func temporary<T>(_ type: T.Type, capacity: Int) throws(PDKProfileValueError) {
        if let reservation = try capacityReservation(type, capacity: capacity, dimension: .temporaryBytes) {
            temporaryReservations.append(reservation)
        }
    }
    private func capacityReservation<T>(_ type: T.Type, capacity: Int,
        dimension: PDKAdmissionResourceDimension) throws(PDKProfileValueError) -> PDKAdmissionReservation? {
        try check()
        guard capacity >= 0 else { throw .resource(.arithmeticOverflow(dimension)) }
        let (amount, overflow) = UInt64(capacity).multipliedReportingOverflow(by: UInt64(MemoryLayout<T>.stride))
        guard !overflow else { throw .resource(.arithmeticOverflow(dimension)) }
        guard let resources, amount > 0 else { return nil }
        do { return try resources.reserve(PDKAdmissionCost(dimension: dimension, amount: amount)) }
        catch { throw .resource(error) }
    }
    func map<T, U>(_ values: [T], _ transform: (T) throws(PDKProfileValueError) -> U) throws(PDKProfileValueError) -> [U] {
        try temporary(U.self, capacity: values.count)
        var result: [U] = []; result.reserveCapacity(values.count)
        for value in values { try step(); result.append(try transform(value)) }
        return result
    }
    func first<T>(_ values: [T], where predicate: (T) throws(PDKProfileValueError) -> Bool) throws(PDKProfileValueError) -> T? {
        for value in values { try step(); if try predicate(value) { return value } }
        return nil
    }
    func contains<T>(_ values: [T], where predicate: (T) throws(PDKProfileValueError) -> Bool) throws(PDKProfileValueError) -> Bool {
        for value in values { try step(); if try predicate(value) { return true } }
        return false
    }
    func sorted<T>(_ values: [T], ownedResult: Bool = false, by predicate: (T, T) throws(PDKProfileValueError) -> Bool) throws(PDKProfileValueError) -> [T] {
        if !ownedResult { try temporary(T.self, capacity: values.count) }
        var result: [T] = []; result.reserveCapacity(values.count)
        for value in values { try step(); result.append(value) }
        // Heap sorting owns one explicit result array and no hidden merge buffer.
        func sift(_ start: Int, _ end: Int) throws(PDKProfileValueError) {
            var root = start
            while root < end / 2 {
                try step()
                var child = root * 2 + 1
                if child + 1 < end { try step(); if try predicate(result[child], result[child + 1]) { child += 1 } }
                try step()
                guard try predicate(result[root], result[child]) else { return }
                try step(); result.swapAt(root, child); root = child
            }
        }
        if result.count > 1 {
            for start in stride(from: result.count / 2 - 1, through: 0, by: -1) { try sift(start, result.count) }
            for end in stride(from: result.count - 1, through: 1, by: -1) {
                try step(); result.swapAt(0, end); try sift(0, end)
            }
        }
        return result
    }
    func filter<T>(_ values: [T], _ predicate: (T) throws(PDKProfileValueError) -> Bool) throws(PDKProfileValueError) -> [T] {
        try temporary(T.self, capacity: values.count)
        var result: [T] = []; result.reserveCapacity(values.count)
        for value in values { try step(); if try predicate(value) { result.append(value) } }
        return result
    }
    func unique(_ values: [String]) throws(PDKProfileValueError) {
        for (index, value) in values.enumerated() {
            try step()
            try PDKProfileWire.id(value, resources: resources)
            for prior in values[..<index] {
                guard try !equal(prior, value) else { throw .duplicateKey(context(value)) }
            }
        }
    }
    func byteCount(_ value: String) throws(PDKProfileValueError) -> UInt64 {
        var count: UInt64 = 0
        for _ in value.utf8 {
            try step()
            let (next, overflow) = count.addingReportingOverflow(1)
            guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
            count = next
        }
        return count
    }
    func comparison(_ lhs: String, _ rhs: String) throws(PDKProfileValueError) {
        let left = try byteCount(lhs), right = try byteCount(rhs)
        let (amount, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw .resource(.arithmeticOverflow(.parserWork)) }
        try step(amount)
    }
    func equal(_ lhs: String, _ rhs: String) throws(PDKProfileValueError) -> Bool {
        try comparison(lhs, rhs); return lhs == rhs
    }
    func equal(_ lhs: String?, _ rhs: String?) throws(PDKProfileValueError) -> Bool {
        try step()
        switch (lhs, rhs) {
        case (.some(let lhs), .some(let rhs)): return try equal(lhs, rhs)
        case (.none, .none): return true
        default: return false
        }
    }
    func less(_ lhs: String, _ rhs: String) throws(PDKProfileValueError) -> Bool {
        try comparison(lhs, rhs); return lhs < rhs
    }
    func selectionLess(_ lhs: PDKProfileSelection, _ rhs: PDKProfileSelection) throws(PDKProfileValueError) -> Bool {
        if try equal(lhs.requirementID, rhs.requirementID) { return try less(lhs.cornerID ?? "", rhs.cornerID ?? "") }
        return try less(lhs.requirementID, rhs.requirementID)
    }
    func contains(_ values: [String], _ value: String) throws(PDKProfileValueError) -> Bool {
        try contains(values, where: { (candidate: String) throws(PDKProfileValueError) in try equal(candidate, value) })
    }
    func insert(_ value: String, into values: inout [String]) throws(PDKProfileValueError) -> Bool {
        if try contains(values, value) { return false }
        try step(); values.append(value); return true
    }
    func equal(_ lhs: ArtifactReference, _ rhs: ArtifactReference) throws(PDKProfileValueError) -> Bool {
        try step()
        guard lhs.byteCount == rhs.byteCount, lhs.digest.algorithm == rhs.digest.algorithm else { return false }
        guard try equal(lhs.digest.hexadecimalValue, rhs.digest.hexadecimalValue) else { return false }
        guard try equal(lhs.descriptor.role.rawValue, rhs.descriptor.role.rawValue) else { return false }
        guard try equal(lhs.descriptor.kind.rawValue, rhs.descriptor.kind.rawValue) else { return false }
        return try equal(lhs.descriptor.format.rawValue, rhs.descriptor.format.rawValue)
    }
    func equal(_ lhs: [String], _ rhs: [String]) throws(PDKProfileValueError) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices { if try !equal(lhs[index], rhs[index]) { return false } }
        return true
    }
    func equal(_ lhs: PDKProfileSource, _ rhs: PDKProfileSource) throws(PDKProfileValueError) -> Bool {
        guard try equal(lhs.sourceKey, rhs.sourceKey) else { return false }
        guard try equal(lhs.assetID, rhs.assetID) else { return false }
        guard try equal(lhs.reference, rhs.reference) else { return false }
        return try equal(lhs.logicalRoutes, rhs.logicalRoutes)
    }
    func equal(_ lhs: PDKSourceDependency, _ rhs: PDKSourceDependency) throws(PDKProfileValueError) -> Bool {
        try step()
        guard lhs.statementByteOffset == rhs.statementByteOffset, lhs.statementOrdinal == rhs.statementOrdinal,
              lhs.lexicalOrder == rhs.lexicalOrder else { return false }
        guard try equal(lhs.parentSourceKey, rhs.parentSourceKey) else { return false }
        guard try equal(lhs.parentReference, rhs.parentReference) else { return false }
        guard try equal(lhs.directiveKind, rhs.directiveKind) else { return false }
        guard try equal(lhs.literalRoute, rhs.literalRoute) else { return false }
        guard try equal(lhs.childSourceKey, rhs.childSourceKey) else { return false }
        guard try equal(lhs.childReference, rhs.childReference) else { return false }
        guard try equal(lhs.selectedSection, rhs.selectedSection) else { return false }
        return try equal(lhs.preprocessingIdentity, rhs.preprocessingIdentity)
    }
    func asciiLowerEqual(_ lhs: String, prefixLeft: Bool, _ rhs: String, prefixRight: Bool) throws(PDKProfileValueError) -> Bool {
        for byte in lhs.utf8 {
                try step()
                guard byte < 128 else { throw .resource(.unsupportedBudgetCapability("Cooperative Unicode kind normalization")) }
        }
        for byte in rhs.utf8 {
            try step()
            guard byte < 128 else { throw .resource(.unsupportedBudgetCapability("Cooperative Unicode kind normalization")) }
        }
        var left = lhs.utf8.makeIterator(), right = rhs.utf8.makeIterator()
        func prefixByte(_ index: Int) -> UInt8 { switch index { case 0: 112; case 1: 100; case 2: 107; default: 46 } }
        var li = 0, ri = 0
        while true {
            try step()
            let a: UInt8?
            if prefixLeft && li < 4 { a = prefixByte(li); li += 1 } else { a = left.next() }
            let b: UInt8?
            if prefixRight && ri < 4 { b = prefixByte(ri); ri += 1 } else { b = right.next() }
            func lowered(_ byte: UInt8) -> UInt8 { (65...90).contains(byte) ? byte + 32 : byte }
            if a.map(lowered) != b.map(lowered) { return false }
            if a == nil { return true }
        }
    }
    func hasNormalizedPrefix(_ value: String) throws(PDKProfileValueError) -> Bool {
        var iterator = value.utf8.makeIterator()
        func prefixByte(_ index: Int) -> UInt8 { switch index { case 0: 112; case 1: 100; case 2: 107; default: 46 } }
        for index in 0..<4 {
            try step()
            guard let byte = iterator.next() else { return false }
            let lower = (65...90).contains(byte) ? byte + 32 : byte
            if lower != prefixByte(index) { return false }
        }
        return true
    }
    func technologyKind(_ kind: ArtifactKind) throws(PDKProfileValueError) -> Bool {
        if resources == nil { return PDKIdentityDescriptorPolicy.normalizedKind(kind) == "pdk.technology" }
        return try asciiLowerEqual(kind.rawValue, prefixLeft: !hasNormalizedPrefix(kind.rawValue), "pdk.technology", prefixRight: false)
    }
    func matches(_ asset: PDKAssetReference, reference: ArtifactReference) throws(PDKProfileValueError) -> Bool {
        if resources == nil {
            let locator: ArtifactLocator
            do { locator = try asset.artifactLocator() } catch { throw .conflictingReference(asset.assetID) }
            return PDKIdentityDescriptorPolicy.matches(locator, reference: reference)
                && (asset.sha256.map { $0.lowercased() == reference.digest.hexadecimalValue } ?? true)
                && (asset.byteCount.map { $0 >= 0 && UInt64($0) == reference.byteCount } ?? true)
        }
        try PDKProfileWire.route(asset.path, resources: resources)
        for byte in asset.path.utf8 {
            try step()
            guard byte >= 32, byte != 127 else { throw .conflictingReference(context(asset.assetID)) }
        }
        guard !asset.path.hasPrefix("~"), try equal(reference.descriptor.role.rawValue, "input"),
              try equal(asset.format.rawValue, reference.descriptor.format.rawValue),
              try asciiLowerEqual(asset.kind.rawValue, prefixLeft: true, reference.kind.rawValue, prefixRight: !hasNormalizedPrefix(reference.kind.rawValue)) else { return false }
        if let digest = asset.sha256 {
            // Hex digest syntax is ASCII; non-ASCII declarations cannot match a SHA-256 value.
            for byte in digest.utf8 { try step(); if byte >= 128 { return false } }
            guard try asciiLowerEqual(digest, prefixLeft: false, reference.digest.hexadecimalValue, prefixRight: false) else { return false }
        }
        if let byteCount = asset.byteCount { try step(); guard byteCount >= 0, UInt64(byteCount) == reference.byteCount else { return false } }
        return true
    }
    func context(_ value: String) -> String { resources == nil ? value : "Profile construction" }
    func retainTemporaries() -> [PDKAdmissionReservation] { temporaryReservations }
}
