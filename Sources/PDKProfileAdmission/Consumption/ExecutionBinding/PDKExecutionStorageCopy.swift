import CircuiteFoundation
import PDKCore

struct PDKExecutionStorageCopy {
    let work: PDKConsumptionWork
    func digest(_ value: ContentDigest, owners: inout PDKAdmissionCollection<PDKAdmissionReservation>)
        throws(PDKProfileConsumptionError) -> ContentDigest {
        let hex = try work.copy(value.hexadecimalValue, owners: &owners)
        let size = try work.bytes(hex), lease = try work.reserve(.temporaryBytes, size)
        defer { withExtendedLifetime(lease) {} }
        try work.charge(.parserWork, size)
        do { return try ContentDigest(algorithm: value.algorithm, hexadecimalValue: hex) }
        catch { throw .invalidEvidenceReference }
    }
    func reference(_ value: ArtifactReference, owners: inout PDKAdmissionCollection<PDKAdmissionReservation>)
        throws(PDKProfileConsumptionError) -> ArtifactReference {
        let digest = try digest(value.digest, owners: &owners)
        let kind = try work.copy(value.descriptor.kind.rawValue, owners: &owners)
        let format = try work.copy(value.descriptor.format.rawValue, owners: &owners)
        try work.charge(.parserWork, work.bytes(kind)); try work.charge(.parserWork, work.bytes(format))
        do {
            let descriptor = try ArtifactDescriptor(role: value.descriptor.role, kind: ArtifactKind(rawValue: kind), format: ArtifactFormat(rawValue: format))
            return try ArtifactReference(id: ArtifactID(digest: digest, byteCount: value.byteCount), descriptor: descriptor)
        } catch { throw .invalidEvidenceReference }
    }
    func optional(_ value: String?, owners: inout PDKAdmissionCollection<PDKAdmissionReservation>)
        throws(PDKProfileConsumptionError) -> String? {
        if let value { return try work.copy(value, owners: &owners) }; return nil
    }
    func edge(_ value: PDKSourceDependency, owners: inout PDKAdmissionCollection<PDKAdmissionReservation>)
        throws(PDKProfileConsumptionError) -> PDKSourceDependency {
        let parentKey = try work.copy(value.parentSourceKey, owners: &owners)
        let parent = try reference(value.parentReference, owners: &owners)
        let directive = try work.copy(value.directiveKind, owners: &owners)
        let route = try work.copy(value.literalRoute, owners: &owners)
        let childKey = try work.copy(value.childSourceKey, owners: &owners)
        let child = try reference(value.childReference, owners: &owners)
        let section = try optional(value.selectedSection, owners: &owners)
        let preprocessing = try work.copy(value.preprocessingIdentity, owners: &owners)
        return try work.value { () throws(PDKProfileValueError) -> PDKSourceDependency in
            try .init(parentSourceKey: parentKey, parentReference: parent, statementByteOffset: value.statementByteOffset,
                statementOrdinal: value.statementOrdinal, directiveKind: directive, literalRoute: route,
                childSourceKey: childKey, childReference: child, selectedSection: section,
                preprocessingIdentity: preprocessing, lexicalOrder: value.lexicalOrder, resources: work.resources)
        }
    }
    func source(_ value: PDKConsumedSource, owners: inout PDKAdmissionCollection<PDKAdmissionReservation>)
        throws(PDKProfileConsumptionError) -> PDKConsumedSource {
        let key = try work.copy(value.sourceKey, owners: &owners)
        let reference = try reference(value.reference, owners: &owners)
        let corner = try optional(value.cornerID, owners: &owners)
        let section = try optional(value.selectedSection, owners: &owners)
        let preprocessing = try work.copy(value.preprocessingIdentity, owners: &owners)
        let edge: PDKSourceDependency?
        if let incoming = value.incomingDependency { edge = try self.edge(incoming, owners: &owners) } else { edge = nil }
        return try work.value { () throws(PDKProfileValueError) -> PDKConsumedSource in
            try .init(occurrenceID: value.occurrenceID, sourceKey: key, reference: reference, cornerID: corner,
                selectedSection: section, preprocessingIdentity: preprocessing, parentOccurrenceID: value.parentOccurrenceID,
                incomingDependency: edge, resources: work.resources)
        }
    }
}
