import CircuiteFoundationFileSystem

struct CLIInputProbedControl: ArtifactSourceControl {
    let base: any ArtifactSourceControl
    let probe: CLIInputRootProbe
    func check() throws(ArtifactSourceControlError) { try base.check() }
    func charge(_ work: ArtifactSourceWork) throws(ArtifactSourceControlError) {
        try base.charge(work)
        probe.state.withLock { $0.readBytes += work.readBytes }
    }
    func retain(_ extent: ArtifactSourceExtent) throws(ArtifactSourceControlError) -> any ArtifactSourceRetention {
        try base.retain(extent)
    }
}
