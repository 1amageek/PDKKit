import PDKCore

struct PDKStageProjectionBuilder {
    let profile: AdmittedPDKProfile
    let requested: PDKConsumerRequirement
    let work: PDKConsumptionWork

    func build() throws(PDKProfileConsumptionError) -> PDKStageProjection {
        try work.check()
        var selections = PDKAdmissionCollection<PDKProfileSelection>()
        var corners = PDKAdmissionCollection<PDKProfileCorner>()
        for id in requested.requirementIDs {
            var found = false
            for requirement in profile.claim.definition.requirements {
                if try work.equal(id, requirement.requirementID) { found = true; break }
            }
            guard found else { throw .invalidStageSubset }
        }
        for selection in profile.claim.selections {
            guard try work.contains(selection.requirementID, in: requested.requirementIDs) else { continue }
            if let corner = selection.cornerID, try !work.contains(corner, in: requested.cornerIDs) { continue }
            try work.append(selection, to: &selections)
        }
        for id in requested.requirementIDs {
            var found = false
            for selection in selections { if try work.equal(id, selection.requirementID) { found = true; break } }
            guard found else { throw .invalidStageSubset }
        }
        for corner in profile.claim.corners {
            guard try work.contains(corner.cornerID, in: requested.cornerIDs) else { continue }
            var used = false
            for selection in selections { if try work.equal(corner.cornerID, selection.cornerID) { used = true; break } }
            guard used else { throw .invalidStageSubset }; try work.append(corner, to: &corners)
        }
        guard corners.count == requested.cornerIDs.count else { throw .invalidStageSubset }
        var roots = PDKAdmissionCollection<Int>()
        for root in profile.rootOccurrences {
            try work.step(); guard let selection = root.selection else { continue }
            for selected in selections {
                if try work.equal(selection, selected) {
                    if try !work.contains(root.nodeID, in: roots) { try work.append(root.nodeID, to: &roots) }
                    break
                }
            }
        }
        var inputs = PDKAdmissionCollection<PDKProfileSourceInput>()
        var sources = PDKAdmissionCollection<PDKConsumedSource>()
        for input in profile.sourceInputs {
            try work.step()
            let isRoot = try work.contains(input.nodeID, in: roots)
            let parent = try localID(input.incomingEvent?.parentNodeID, inputs: inputs)
            guard isRoot || parent != nil else { continue }
            guard isRoot ? input.incomingEvent == nil : parent != nil else { throw .invalidProjection }
            let source = try work.value { () throws(PDKProfileValueError) -> PDKConsumedSource in try PDKConsumedSource(occurrenceID: UInt64(inputs.count),
                sourceKey: input.sourceKey, reference: input.reference, cornerID: input.context.cornerID,
                selectedSection: input.context.selectedSection, preprocessingIdentity: input.context.preprocessingIdentity,
                parentOccurrenceID: parent, incomingDependency: input.incomingEvent?.edge, resources: work.resources) }
            try work.append(input, to: &inputs); try work.append(source, to: &sources)
        }
        guard !inputs.isEmpty else { throw .invalidProjection }
        var known = PDKAdmissionCollection<PDKConsumedMapping>()
        for facts in profile.sourceFacts {
            guard try work.contains(facts.input.nodeID, in: roots) else { continue }
            for fact in facts.mappings {
                guard let id = try localID(fact.input.nodeID, inputs: inputs) else { throw .invalidProjection }
                let mapping = try record(fact, id: id)
                var duplicate = false
                for prior in known { if try work.equal(mapping, prior) { duplicate = true; break } }
                if !duplicate { try work.append(mapping, to: &known) }
            }
        }
        var mappings = PDKAdmissionCollection<PDKStageMappingRequirement>()
        for root in roots {
            guard let local = try localID(root, inputs: inputs) else { throw .invalidProjection }
            for occurrence in profile.rootOccurrences {
                try work.step(); guard occurrence.nodeID == root, let selection = occurrence.selection else { continue }
                var chosen = false
                for candidate in selections { if try work.equal(candidate, selection) { chosen = true; break } }
                guard chosen else { continue }
                let requirement = try requirement(selection.requirementID)
                for kind in requirement.demandedFactKinds {
                    if try special(kind) { continue }
                    try add(.factKind(kind), root: root, local: local, inputs: inputs, output: &mappings)
                }
                for index in selection.sourceKeys.indices {
                    guard try work.equal(selection.sourceKeys[index], inputs[Int(local)].sourceKey) else { continue }
                    for mapping in profile.manifest.manifest.crossViewMappings {
                        try work.step()
                        guard mapping.view == requirement.view,
                              try work.equal(mapping.assetID, selection.assetIDs[index]) else { continue }
                        let inCorner: Bool
                        if let corner = selection.cornerID { inCorner = try work.contains(corner, in: mapping.cornerIDs) }
                        else { inCorner = mapping.cornerIDs.isEmpty }
                        guard inCorner else { continue }
                        for name in mapping.logicalNames { try add(.name(name), root: root, local: local, inputs: inputs, output: &mappings) }
                        for name in mapping.physicalNames { try add(.name(name), root: root, local: local, inputs: inputs, output: &mappings) }
                        for id in mapping.layerIDs {
                            var found = false
                            for layer in profile.manifest.manifest.layers {
                                if try work.equal(id, layer.layerID) {
                                    try add(.layer(layer), root: root, local: local, inputs: inputs, output: &mappings); found = true; break
                                }
                            }
                            guard found else { throw .invalidProjection }
                        }
                        for id in mapping.deviceIDs {
                            var found = false
                            for device in profile.manifest.manifest.devices {
                                if try work.equal(id, device.deviceID) {
                                    try add(.device(device), root: root, local: local, inputs: inputs, output: &mappings); found = true; break
                                }
                            }
                            guard found else { throw .invalidProjection }
                        }
                    }
                }
            }
        }
        var storage = PDKAdmissionCollection<PDKAdmissionReservation>()
        let stage = try work.copy(requested.stageID, owners: &storage)
        let config = try work.copy(requested.configurationIdentity, owners: &storage)
        if let lease = try work.capacity(String.self, requested.requirementIDs.count, dimension: .liveOwnedBytes) { try work.append(lease, to: &storage) }
        if let lease = try work.capacity(String.self, corners.count, dimension: .liveOwnedBytes) { try work.append(lease, to: &storage) }
        var requirementIDs: [String] = []; requirementIDs.reserveCapacity(requested.requirementIDs.count)
        for selection in selections {
            if try !work.contains(selection.requirementID, in: requirementIDs) { try work.step(); requirementIDs.append(selection.requirementID) }
        }
        var cornerIDs: [String] = []; cornerIDs.reserveCapacity(corners.count)
        for corner in corners { try work.step(); cornerIDs.append(corner.cornerID) }
        let requirement = try work.value { () throws(PDKProfileValueError) -> PDKConsumerRequirement in try PDKConsumerRequirement(stageID: stage, requirementIDs: requirementIDs,
            cornerIDs: cornerIDs, configurationIdentity: config, resources: work.resources) }
        try work.append(work.reserve(.liveOwnedBytes, 64), to: &storage)
        let identity = try PDKStageCanonicalEncoding(work: work).digest(profile: profile.claim.semanticSelectionDigest,
            requirement: requirement, sources: sources, corners: corners, selections: selections, mappings: mappings)
        try work.check()
        return .init(profile: profile, requirement: requirement, identity: identity, inputs: inputs, sources: sources,
            corners: corners, selections: selections, mappings: mappings, known: known, storage: storage)
    }
    private func localID(_ node: Int?, inputs: PDKAdmissionCollection<PDKProfileSourceInput>) throws(PDKProfileConsumptionError) -> UInt64? {
        guard let node else { return nil }
        for index in inputs.indices { try work.step(); if inputs[index].nodeID == node { return UInt64(index) } }; return nil
    }
    private func record(_ fact: PDKProfileMappingFact, id: UInt64) throws(PDKProfileConsumptionError) -> PDKConsumedMapping {
        try work.value { () throws(PDKProfileValueError) -> PDKConsumedMapping in try .init(occurrenceID: id, factKind: fact.factKind, name: fact.name, terminals: fact.terminals,
            layerNumber: fact.layerNumber, layerPurpose: fact.layerPurpose, resources: work.resources) }
    }
    private func requirement(_ id: String) throws(PDKProfileConsumptionError) -> PDKViewRequirement {
        for requirement in profile.claim.definition.requirements { if try work.equal(id, requirement.requirementID) { return requirement } }
        throw .invalidProjection
    }
    private func special(_ kind: String) throws(PDKProfileConsumptionError) -> Bool {
        if try work.equal("sourcePVT", kind) { return true }
        if try work.equal("operatingTemperature", kind) { return true }
        if try work.equal("dependencyClosure", kind) { return true }
        return try work.equal("selectedSection", kind)
    }
    private func add(_ condition: PDKStageMappingRequirement.Condition, root: Int, local: UInt64,
                     inputs: PDKAdmissionCollection<PDKProfileSourceInput>, output: inout PDKAdmissionCollection<PDKStageMappingRequirement>)
        throws(PDKProfileConsumptionError) {
        var candidates = PDKAdmissionCollection<PDKConsumedMapping>()
        for facts in profile.sourceFacts {
            try work.step(); guard facts.input.nodeID == root else { continue }
            for fact in facts.mappings {
                guard try PDKStageMappingRequirement.accepts(fact, condition: condition, work: work),
                      let id = try localID(fact.input.nodeID, inputs: inputs) else { continue }
                let mapping = try record(fact, id: id)
                var duplicate = false
                for prior in candidates { if try work.equal(mapping, prior) { duplicate = true; break } }
                if !duplicate { try work.append(mapping, to: &candidates) }
            }
        }
        guard !candidates.isEmpty else { throw .invalidProjection }
        try work.append(.init(rootOccurrenceID: local, condition: condition, candidates: candidates), to: &output)
    }
}
