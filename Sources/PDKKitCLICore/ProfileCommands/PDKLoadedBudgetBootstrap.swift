import CircuiteFoundation
import CircuiteFoundationFileSystem

/// Retains the exact observed pre-budget input independently of profile accounting.
public struct PDKLoadedBudgetBootstrap: Sendable {
    public let parsed: PDKBudgetBootstrapResult
    public let reference: ArtifactReference
    public let acquisition: PDKBudgetAcquisitionObservations
    private let source: ArtifactDiscoveredSource
    init(parsed: PDKBudgetBootstrapResult, source: ArtifactDiscoveredSource,
         acquisition: PDKBudgetAcquisitionObservations) {
        self.parsed = parsed; self.reference = source.reference
        self.acquisition = acquisition; self.source = source
    }
}
