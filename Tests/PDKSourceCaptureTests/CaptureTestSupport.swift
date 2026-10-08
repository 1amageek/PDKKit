import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation

func captureReference(_ bytes: [UInt8]) throws -> ArtifactReference {
    let digest = try SHA256ContentDigester().digest(using: .sha256, limits: .singleBufferMaximum) {
        (lease: borrowing ContentDigestUpdateLease) throws(ContentDigestError) in
        try lease.update(bytes)
    }
    return try ArtifactReference(digest: digest.digest, byteCount: UInt64(bytes.count), descriptor: ArtifactDescriptor(role: .input, kind: .report, format: .json))
}

func captureBudget(total: UInt64 = 64, pages: UInt64 = 16) throws -> ArtifactAccessBudget {
    try ArtifactAccessBudget(maximumPageByteCount: min(total, 4), maximumTotalByteCount: total, maximumPageCount: pages, maximumWorkUnitCount: 64, maximumDurationNanoseconds: 5_000_000_000)
}

func captureIntent(_ reference: ArtifactReference, budget: ArtifactAccessBudget? = nil) throws -> ArtifactAccessIntent {
    try ArtifactAccessIntent(
        expectedReference: reference,
        availability: .local(artifactID: reference.id, rootID: ArtifactRootID(rawValue: "test"), relativePath: ArtifactRelativePath(segments: ["input.json"])),
        operation: .read,
        budget: try budget ?? captureBudget()
    )
}

func capturePage(
    _ reference: ArtifactReference,
    bytes: [UInt8],
    offset: UInt64 = 0,
    terminal: Bool = true,
    cumulative: UInt64? = nil,
    pageCount: UInt64 = 1,
    workUnits: UInt64 = 1,
    elapsed: UInt64 = 1,
    claimedCount: UInt64? = nil,
    receiptWorkUnits: UInt64? = nil
) throws -> ArtifactReadPage {
    let count = claimedCount ?? UInt64(bytes.count)
    let work = ArtifactAccessWorkReport(pageCount: pageCount, workUnitCount: workUnits, elapsedNanoseconds: elapsed)
    return try ArtifactReadPage(
        offset: offset,
        bytes: CaptureTestBytes(storage: bytes, byteCount: count),
        cumulativeByteCount: cumulative ?? offset + count,
        cumulativeWork: work,
        completion: terminal ? .complete : .more,
        finalReceipt: terminal ? ArtifactAccessReceipt(
            observedArtifactID: reference.id,
            totalByteCount: offset + count,
            cumulativeWork: ArtifactAccessWorkReport(pageCount: pageCount, workUnitCount: receiptWorkUnits ?? workUnits, elapsedNanoseconds: elapsed)
        ) : nil
    )
}
