import CircuiteFoundation
import PDKCore

struct PDKManifestLoadingWork {
    let resources: any PDKAdmissionResourceAccounting
    func check() throws(PDKBoundedManifestLoadingError) {
        do { try resources.check() } catch { throw .resource(error) }
        guard !Task.isCancelled else { throw .resource(.cancelled) }
    }
    func scan(_ value: String) throws(PDKBoundedManifestLoadingError) {
        for _ in value.utf8 {
            try check()
            do { try resources.charge(PDKAdmissionCost(dimension: .parserWork, amount: 1)) }
            catch { throw .resource(error) }
        }
        try check()
    }
    func equal(_ lhs: ArtifactReference, _ rhs: ArtifactReference) throws(PDKBoundedManifestLoadingError) -> Bool {
        try scan(lhs.digest.hexadecimalValue); try scan(rhs.digest.hexadecimalValue)
        try scan(lhs.descriptor.role.rawValue); try scan(rhs.descriptor.role.rawValue)
        try scan(lhs.descriptor.kind.rawValue); try scan(rhs.descriptor.kind.rawValue)
        try scan(lhs.descriptor.format.rawValue); try scan(rhs.descriptor.format.rawValue)
        let equal = lhs == rhs
        try check()
        return equal
    }
    func descriptorMatches(_ lhs: ArtifactDescriptor, _ rhs: ArtifactDescriptor) throws(PDKBoundedManifestLoadingError) -> Bool {
        try scan(lhs.role.rawValue); try scan(rhs.role.rawValue)
        try scan(lhs.kind.rawValue); try scan(rhs.kind.rawValue)
        try scan(lhs.format.rawValue); try scan(rhs.format.rawValue)
        let equal = lhs == rhs
        try check()
        return equal
    }
    func json(_ descriptor: ArtifactDescriptor) throws(PDKBoundedManifestLoadingError) {
        try scan(descriptor.format.rawValue)
        guard descriptor.format == .json else { throw .invalidFormat }
        try check()
    }
}
