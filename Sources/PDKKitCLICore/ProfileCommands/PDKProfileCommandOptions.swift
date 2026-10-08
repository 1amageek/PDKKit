import Foundation
import CircuiteFoundation
import PDKCore
import PDKProfileAdmission
import PDKSourceCapture

/// Fixed option slots borrow process-owned arguments until accounted conversion.
struct PDKProfileCommandOptions {
    enum Verb: String { case propose, plan, admit, replay }
    let verb: Verb
    let root: PDKProfileAuthorizedRoot
    let budgetPath: ArtifactRelativePath
    private let availabilityPath: String
    private let availabilityDigest: String
    private let availabilityCount: String
    private let authoringPath: String?
    private let authoringDigest: String?
    private let authoringCount: String?

    init(arguments: [String], start: Int, policy: PDKBudgetBootstrapPolicy) throws {
        guard start >= 0, start < arguments.count, arguments.count - start <= 20,
              arguments.count - start >= 14, arguments[start] == "profile" else { throw PDKProfileCommandError.invalidArguments }
        var verbBytes = 0
        for _ in arguments[start + 1].utf8 {
            verbBytes += 1; guard verbBytes <= 7 else { throw PDKProfileCommandError.invalidArguments }
        }
        guard let verb = Verb(rawValue: arguments[start + 1]) else { throw PDKProfileCommandError.invalidArguments }
        var root: String?, rootID: String?, budget: String?, availability: String?, digest: String?, count: String?
        var authoring: String?, authoringDigest: String?, authoringCount: String?
        var seen: UInt16 = 0, index = start + 2
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw PDKProfileCommandError.invalidArguments }
            let flag = arguments[index], value = arguments[index + 1]
            // Fixed vocabulary bounds comparison before the invocation accountant exists.
            var flagBytes = 0
            for _ in flag.utf8 { flagBytes += 1; guard flagBytes <= 32 else { throw PDKProfileCommandError.invalidArguments } }
            let bit: UInt16
            switch flag {
            case "--input-root": bit = 1; root = value
            case "--input-root-id": bit = 2; rootID = value
            case "--budget": bit = 4; budget = value
            case "--availability": bit = 8; availability = value
            case "--availability-sha256": bit = 16; digest = value
            case "--availability-bytes": bit = 32; count = value
            case "--authoring": bit = 64; authoring = value
            case "--authoring-sha256": bit = 128; authoringDigest = value
            case "--authoring-bytes": bit = 256; authoringCount = value
            default: throw PDKProfileCommandError.invalidArguments
            }
            guard seen & bit == 0 else { throw PDKProfileCommandError.invalidArguments }
            seen |= bit; index += 2
        }
        guard seen == (verb == .propose ? 511 : 63), let root, let rootID, let budget,
              let availability, let digest, let count else { throw PDKProfileCommandError.invalidArguments }
        for value in [root, rootID, budget] {
            var bytes: UInt64 = 0
            for _ in value.utf8 {
                bytes += 1
                guard bytes <= policy.maximumByteCount else { throw PDKProfileCommandError.invalidArguments }
            }
        }
        guard root.hasPrefix("/"), !rootID.isEmpty else { throw PDKProfileCommandError.invalidArguments }
        self.root = try PDKProfileAuthorizedRoot(rootID: ArtifactRootID(rawValue: rootID),
            rootURL: URL(fileURLWithPath: root, isDirectory: true))
        self.budgetPath = try ArtifactRelativePath(segments: budget.split(separator: "/", omittingEmptySubsequences: false).map(String.init))
        self.verb = verb; availabilityPath = availability; availabilityDigest = digest; availabilityCount = count
        self.authoringPath = authoring; self.authoringDigest = authoringDigest; self.authoringCount = authoringCount
    }

    func availability(work: PDKProfileCommandWork, budget: PDKAdmissionBudget,
                      reservations: inout [PDKAdmissionReservation]) throws -> PDKProfileExactBinding {
        try binding(path: availabilityPath, digest: availabilityDigest, count: availabilityCount,
            descriptor: PDKProfileCLIAvailability.artifactDescriptor, work: work, budget: budget, reservations: &reservations)
    }
    func authoring(work: PDKProfileCommandWork, budget: PDKAdmissionBudget,
                   reservations: inout [PDKAdmissionReservation]) throws -> PDKProfileExactBinding {
        guard let authoringPath, let authoringDigest, let authoringCount else { throw PDKProfileCommandError.invalidArguments }
        return try binding(path: authoringPath, digest: authoringDigest, count: authoringCount,
            descriptor: PDKProfileCLIAuthoring.artifactDescriptor, work: work, budget: budget, reservations: &reservations)
    }
    private func binding(path: String, digest: String, count: String, descriptor: ArtifactDescriptor,
                         work: PDKProfileCommandWork, budget: PDKAdmissionBudget,
                         reservations: inout [PDKAdmissionReservation]) throws -> PDKProfileExactBinding {
        let pathBytes = try work.bytes(path)
        _ = try work.bytes(count)
        var hexadecimalCount = 0
        for byte in digest.utf8 {
            try work.step(); hexadecimalCount += 1
            guard hexadecimalCount <= 64, (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte) else {
                throw PDKProfileCommandError.invalidArguments
            }
        }
        guard hexadecimalCount == 64, let byteCount = UInt64(count), byteCount > 0,
              let pageLimit = budget.limits[.pages], let workLimit = budget.limits[.parserWork] else {
            throw PDKProfileCommandError.invalidArguments
        }
        var segmentCount = 1
        for byte in path.utf8 {
            try work.step()
            if byte == 47 { segmentCount += 1 }
            guard segmentCount <= Int(UInt16.max) else { throw PDKProfileCommandError.invalidArguments }
        }
        let scratch = try work.reserve(Substring.self, count: segmentCount, dimension: .temporaryBytes)
        defer { withExtendedLifetime(scratch) {} }
        reservations.append(try work.reserve(String.self, count: segmentCount))
        let (ownedBytes, overflow) = pathBytes.addingReportingOverflow(64)
        guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.liveOwnedBytes) }
        reservations.append(try work.resources.reserve(.init(dimension: .liveOwnedBytes, amount: ownedBytes)))
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        var segments: [String] = []; segments.reserveCapacity(segmentCount)
        for part in parts { try work.step(); segments.append(String(part)) }
        let relative = try ArtifactRelativePath(segments: segments)
        let reference = try ArtifactReference(digest: ContentDigest(algorithm: .sha256, hexadecimalValue: digest),
            byteCount: byteCount, descriptor: descriptor)
        let native = try PDKSourceCapturePolicy.defaultBudget
        let access = try ArtifactAccessBudget(maximumPageByteCount: min(byteCount, native.maximumPageByteCount),
            maximumTotalByteCount: byteCount, maximumPageCount: pageLimit, maximumWorkUnitCount: workLimit,
            maximumDurationNanoseconds: budget.maximumElapsedNanoseconds)
        return .init(reference: reference, rootID: root.rootID, relativePath: relative, budget: access)
    }
}
