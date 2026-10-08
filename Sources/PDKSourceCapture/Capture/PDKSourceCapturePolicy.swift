import CircuiteFoundation

public enum PDKSourceCapturePolicy {
    /// One source, at most 64 MiB; pages are at most 64 KiB. Work includes
    /// backend work, page materialization and the final owned-buffer digest.
    public static var defaultBudget: ArtifactAccessBudget {
        get throws {
            try ArtifactAccessBudget(
                maximumPageByteCount: 65_536,
                maximumTotalByteCount: 67_108_864,
                maximumPageCount: 1_025,
                maximumWorkUnitCount: 4_100,
                maximumDurationNanoseconds: 30_000_000_000
            )
        }
    }
}
