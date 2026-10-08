import CircuiteFoundation
import PDKCore

struct PDKConsumptionComparison {
    let projection: PDKStageProjection
    let work: PDKConsumptionWork
    func match(_ claim: PDKConsumptionClaim) throws(PDKProfileConsumptionError) -> PDKMatchedConsumption {
        try work.check()
        guard try work.equal(claim.stageRequirement.stageID, projection.requirement.stageID),
              try work.equal(claim.stageRequirement.configurationIdentity, projection.requirement.configurationIdentity),
              try sameSet(claim.stageRequirement.requirementIDs, projection.requirement.requirementIDs),
              try sameSet(claim.stageRequirement.cornerIDs, projection.requirement.cornerIDs) else { throw .stageMismatch }
        guard try work.equal(claim.profileIdentity, projection.profile.claim.semanticSelectionDigest) else { throw .profileMismatch }
        guard try work.equal(claim.expectedProjectionIdentity, projection.identity) else { throw .projectionMismatch }
        guard claim.actualSources.count == projection.sources.count else { throw .sourceMismatch(min(claim.actualSources.count, projection.sources.count)) }
        for index in projection.sources.indices {
            guard try work.equal(claim.actualSources[index], projection.sources[index]) else { throw .sourceMismatch(index) }
        }
        guard claim.actualCorners.count == projection.corners.count else { throw .cornerMismatch }
        for expected in projection.corners {
            var found = false
            for actual in claim.actualCorners { if try work.equal(actual, expected) { found = true; break } }
            guard found else { throw .cornerMismatch }
        }
        guard claim.actualSelections.count == projection.selections.count else { throw .selectionMismatch }
        for (index, actual) in claim.actualSelections.enumerated() {
            for prior in claim.actualSelections[..<index] { if try work.equal(actual, prior) { throw .selectionMismatch } }
            var found = false
            for expected in projection.selections { if try work.equal(actual, expected) { found = true; break } }
            guard found else { throw .selectionMismatch }
        }
        for (index, actual) in claim.actualMappings.enumerated() {
            for prior in claim.actualMappings[..<index] { if try work.equal(actual, prior) { throw .duplicateMapping(index) } }
            var known = false
            for expected in projection.knownMappings { if try work.equal(actual, expected) { known = true; break } }
            guard known else { throw .unknownMapping(index) }
        }
        for index in projection.mappingRequirements.indices {
            var found = false
            for candidate in projection.mappingRequirements[index].candidates {
                for actual in claim.actualMappings { if try work.equal(candidate, actual) { found = true; break } }
                if found { break }
            }
            guard found else { throw .missingMapping(index) }
        }
        var storage = PDKAdmissionCollection<PDKAdmissionReservation>()
        let evidence = try copy(claim.domainEvidenceReference, owners: &storage)
        try work.check()
        return .init(projection: projection, evidence: evidence, storage: storage)
    }
    private func sameSet(_ a: [String], _ b: [String]) throws(PDKProfileConsumptionError) -> Bool {
        try work.step(); guard a.count == b.count else { return false }
        for value in a { if try !work.contains(value, in: b) { return false } }; return true
    }
    private func copy(_ reference: ArtifactReference, owners: inout PDKAdmissionCollection<PDKAdmissionReservation>)
        throws(PDKProfileConsumptionError) -> ArtifactReference {
        let hex = try work.copy(reference.digest.hexadecimalValue, owners: &owners)
        let kind = try work.copy(reference.descriptor.kind.rawValue, owners: &owners)
        let format = try work.copy(reference.descriptor.format.rawValue, owners: &owners)
        // Foundation validation re-traverses these checked strings; its digest normalization needs one bounded scratch copy.
        let size = try work.bytes(hex)
        let normalization = try work.reserve(.temporaryBytes, size)
        defer { withExtendedLifetime(normalization) {} }
        try work.charge(.parserWork, size)
        try work.charge(.parserWork, work.bytes(kind)); try work.charge(.parserWork, work.bytes(format))
        do {
            let digest = try ContentDigest(algorithm: reference.digest.algorithm, hexadecimalValue: hex)
            let descriptor = try ArtifactDescriptor(role: reference.descriptor.role,
                kind: ArtifactKind(rawValue: kind), format: ArtifactFormat(rawValue: format))
            let result = try ArtifactReference(id: ArtifactID(digest: digest, byteCount: reference.byteCount), descriptor: descriptor)
            try work.check(); return result
        } catch let error as PDKProfileConsumptionError { throw error }
        catch { throw .invalidEvidenceReference }
    }
}
