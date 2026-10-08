import CircuiteFoundationFileSystem

final class PDKBudgetAcquisitionRetention: ArtifactSourceRetention {
    private let release: @Sendable () -> Void
    init(release: @escaping @Sendable () -> Void) { self.release = release }
    deinit { release() }
}
