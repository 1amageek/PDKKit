import CircuiteFoundation
import PDKCore

struct PDKExecutionConsumptionComparison {
    let projection: PDKStageProjection
    let observed: PDKExecutionSourceObservation
    let work: PDKConsumptionWork

    func match(_ claim: PDKExecutionConsumptionClaim) throws(PDKProfileConsumptionError) -> PDKMatchedExecutionConsumption {
        try work.check()
        guard try work.equal(claim.executionInputIdentity, observed.executionInputIdentity) else { throw .executionInputMismatch }
        guard try work.equal(observed.configurationIdentity, projection.requirement.configurationIdentity) else { throw .executionConfigurationMismatch }
        guard claim.sourceBindings.count == projection.sources.count else { throw .executionBindingMismatch(claim.sourceBindings.count) }
        let consumption = try matchPDKConsumption(claim.scopedClaim, against: projection, resources: work.resources)
        var indices = PDKAdmissionCollection<Int>()
        var priorIndex: Int?
        var entryIndex = 0
        for (index, binding) in claim.sourceBindings.enumerated() {
            try work.step()
            guard binding.profileOccurrenceID == UInt64(index) else { throw .executionBindingMismatch(index) }
            let actualIndex = try find(binding.executionOccurrenceID)
            if let priorIndex, actualIndex <= priorIndex { throw .executionBindingMismatch(index) }
            priorIndex = actualIndex
            let actual = observed.sources[actualIndex], expected = projection.sources[index]
            guard try work.equal(actual.sourceKey, expected.sourceKey), try work.equal(actual.reference, expected.reference),
                  try work.equal(actual.cornerID, expected.cornerID), try work.equal(actual.selectedSection, expected.selectedSection),
                  try work.equal(actual.preprocessingIdentity, expected.preprocessingIdentity) else { throw .executionContextMismatch(index) }
            if let parent = expected.parentOccurrenceID {
                guard let parentIndex = Int(exactly: parent), parentIndex < indices.count,
                      actual.parentOccurrenceID == observed.sources[indices[parentIndex]].occurrenceID,
                      let actualEdge = actual.incomingDependency, let expectedEdge = expected.incomingDependency,
                      try work.equal(actualEdge, expectedEdge) else { throw .executionBindingMismatch(index) }
            } else {
                guard entryIndex < claim.entries.count else { throw .executionEntryMismatch(entryIndex) }
                let entry = claim.entries[entryIndex]
                guard entry.profileRootOccurrenceID == expected.occurrenceID,
                      entry.executionRootOccurrenceID == actual.occurrenceID,
                      entry.externalParentOccurrenceID == actual.parentOccurrenceID else { throw .executionEntryMismatch(entryIndex) }
                switch (actual.parentOccurrenceID, actual.incomingDependency, entry.externalParentReference, entry.incomingDependency) {
                case (.none, .none, .none, .none): break
                case (.some(let parentID), .some(let edge), .some(let reference), .some(let claimedEdge)):
                    let parent = observed.sources[try find(parentID)]
                    guard try work.equal(parent.reference, reference), try work.equal(edge, claimedEdge) else { throw .executionEntryMismatch(entryIndex) }
                default: throw .executionEntryMismatch(entryIndex)
                }
                entryIndex += 1
            }
            try work.append(actualIndex, to: &indices)
        }
        guard entryIndex == claim.entries.count else { throw .executionEntryMismatch(entryIndex) }
        for (index, source) in observed.sources.enumerated() {
            try work.step()
            if try work.contains(index, in: indices) { continue }
            var cursor = source.parentOccurrenceID
            while let id = cursor {
                try work.step()
                let parentIndex = try find(id)
                if try work.contains(parentIndex, in: indices) { throw .unrepresentedExecutionContributor(index) }
                cursor = observed.sources[parentIndex].parentOccurrenceID
            }
            for expected in projection.sources {
                try work.step()
                if try work.equal(source.sourceKey, expected.sourceKey) { throw .unrepresentedExecutionContributor(index) }
                if try work.equal(source.reference, expected.reference) { throw .unrepresentedExecutionContributor(index) }
            }
        }
        var owners = PDKAdmissionCollection<PDKAdmissionReservation>()
        let copier = PDKExecutionStorageCopy(work: work)
        var sources = PDKAdmissionCollection<PDKConsumedSource>()
        for source in observed.sources { try work.append(copier.source(source, owners: &owners), to: &sources) }
        var bindings = PDKAdmissionCollection<PDKExecutionSourceBinding>()
        for binding in claim.sourceBindings { try work.append(binding, to: &bindings) }
        var entries = PDKAdmissionCollection<PDKExecutionEntry>()
        for entry in claim.entries {
            let reference: ArtifactReference?
            if let original = entry.externalParentReference { reference = try copier.reference(original, owners: &owners) } else { reference = nil }
            let edge: PDKSourceDependency?
            if let original = entry.incomingDependency { edge = try copier.edge(original, owners: &owners) } else { edge = nil }
            let copied = try work.value { () throws(PDKProfileValueError) -> PDKExecutionEntry in
                try .init(profileRootOccurrenceID: entry.profileRootOccurrenceID, executionRootOccurrenceID: entry.executionRootOccurrenceID,
                    externalParentOccurrenceID: entry.externalParentOccurrenceID, externalParentReference: reference,
                    incomingDependency: edge, resources: work.resources)
            }
            try work.append(copied, to: &entries)
        }
        let input = try copier.digest(observed.executionInputIdentity, owners: &owners)
        let config = try work.copy(observed.configurationIdentity, owners: &owners)
        let grammar = try work.copy(observed.grammarPolicyIdentity, owners: &owners)
        // SHA-256 output has fixed 64-byte hexadecimal storage; admit it before hashing publishes the digest.
        try work.append(work.reserve(.liveOwnedBytes, 64), to: &owners)
        let identity = try PDKExecutionCanonicalEncoding(work: work).digest(projection: projection.identity,
            input: input, bindings: bindings, entries: entries)
        try work.check()
        return .init(consumption: consumption, bindingIdentity: identity, executionInputIdentity: input,
            configurationIdentity: config, grammarPolicyIdentity: grammar, sources: sources, bindings: bindings, entries: entries, storage: owners)
    }
    private func find(_ id: UInt64) throws(PDKProfileConsumptionError) -> Int {
        for (index, source) in observed.sources.enumerated() { try work.step(); if source.occurrenceID == id { return index } }
        throw .unknownExecutionOccurrence(id)
    }
}
