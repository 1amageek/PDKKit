public enum PDKAdmissionResourceDimension: String, Sendable, Hashable, Codable, CaseIterable {
    case searchRoots, scannedEntries, candidates, readBytes, hashedBytes, uniqueSources, pages
    case contextualNodes, dependencyEdges, includeDepth, expansions
    case decodedElements, decodeNesting, scalarBytes, parserWork
    case liveOwnedBytes, temporaryBytes, concurrentAcquisitions, openResources
    case diagnosticEntries, diagnosticBytes

    public var isLiveCapacity: Bool {
        switch self {
        case .includeDepth, .decodeNesting, .liveOwnedBytes, .temporaryBytes, .concurrentAcquisitions, .openResources: true
        default: false
        }
    }
}
