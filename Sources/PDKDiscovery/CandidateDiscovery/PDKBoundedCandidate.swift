import CircuiteFoundationFileSystem
import PDKCore

/// Keep this owner handle while consuming its captured and decoded metadata.
public struct PDKBoundedCandidate: Sendable {
    public let root: PDKBoundedDiscoveryRoot
    public let entry: ArtifactDirectoryEntry
    public let loaded: PDKBoundedLoadedManifest
    private let collectionCapacity: PDKAdmissionReservation

    internal init(root: PDKBoundedDiscoveryRoot, entry: ArtifactDirectoryEntry,
                  loaded: PDKBoundedLoadedManifest, capacity: PDKAdmissionReservation) {
        self.root = root; self.entry = entry; self.loaded = loaded
        collectionCapacity = capacity
    }
    internal var collectionLease: PDKAdmissionReservation { collectionCapacity }
    internal func retaining(_ capacity: PDKAdmissionReservation) -> Self {
        Self(root: root, entry: entry, loaded: loaded, capacity: capacity)
    }
}
