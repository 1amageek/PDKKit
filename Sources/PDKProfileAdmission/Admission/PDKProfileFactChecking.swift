import PDKCore

struct PDKProfileFactChecking {
    let work: PDKAdmissionWork
    func identity(_ facts: PDKProfileSourceFacts, registration: PDKProfileInspectorRegistration,
                  policy: String) throws(PDKProfileAdmissionError) {
        guard try work.equal(facts.parserIdentity, registration.parserIdentity),
              try work.equal(facts.policyIdentity, policy), try work.equal(registration.policyIdentity, policy) else { throw .providerIdentity }
    }
    func demanded(_ kinds: [String], facts: PDKProfileSourceFacts) throws(PDKProfileAdmissionError) {
        for kind in kinds {
            try work.step()
            if try work.equal(kind, "sourcePVT") {
                guard !facts.pvt.isEmpty else { throw .missingCoverage }; continue
            }
            if try work.equal(kind, "operatingTemperature") {
                var found = false
                for fact in facts.temperatures { if try work.equal(fact.kind, "operatingTemperature") { found = true; break } }
                guard found else { throw .missingCoverage }; continue
            }
            if try work.equal(kind, "dependencyClosure") {
                guard !facts.coverage.isEmpty else { throw .missingCoverage }; continue
            }
            if try work.equal(kind, "selectedSection") {
                guard let selected = facts.input.context.selectedSection else { throw .missingCoverage }
                var found = false
                for coverage in facts.coverage { if try work.equal(coverage.observedSection, selected) { found = true; break } }
                guard found else { throw .missingCoverage }; continue
            }
            var found = false
            for mapping in facts.mappings {
                if try work.equal(mapping.factKind, kind), !mapping.name.isEmpty { found = true; break }
            }
            guard found else { throw .missingCoverage }
        }
    }
    func selected(_ selection: PDKProfileSelection, sourceKey: String, manifest: PDKManifest,
                  facts: PDKProfileSourceFacts, plan: PDKProfilePlan) throws(PDKProfileAdmissionError) {
        var requirement: PDKViewRequirement?
        for candidate in plan.definition.requirements {
            if try work.equal(candidate.requirementID, selection.requirementID) { requirement = candidate; break }
        }
        guard let requirement else { throw .mappingMismatch }
        try demanded(requirement.demandedFactKinds, facts: facts)
        if let cornerID = selection.cornerID {
            var corner: PDKProfileCorner?
            for candidate in plan.corners { if try work.equal(candidate.cornerID, cornerID) { corner = candidate; break } }
            guard let corner else { throw .pvtMismatch }
            for fact in facts.pvt {
                try work.step()
                guard try work.equal(fact.pvt.process.name, corner.pvt.process.name),
                      fact.pvt.process.nominal == corner.pvt.process.nominal,
                      fact.pvt.voltage == corner.pvt.voltage,
                      fact.pvt.temperatureCelsius == corner.pvt.temperatureCelsius else { throw .pvtMismatch }
            }
            for fact in facts.temperatures {
                if try work.equal(fact.kind, "operatingTemperature") {
                    guard fact.temperatureCelsius == corner.pvt.temperatureCelsius else { throw .pvtMismatch }
                }
            }
        }
        for index in selection.sourceKeys.indices {
            guard try work.equal(selection.sourceKeys[index], sourceKey) else { continue }
            let assetID = selection.assetIDs[index]
            for mapping in manifest.crossViewMappings {
                try work.step()
                guard mapping.view == requirement.view, try work.equal(mapping.assetID, assetID) else { continue }
                var inCorner = selection.cornerID == nil && mapping.cornerIDs.isEmpty
                if let corner = selection.cornerID {
                    for id in mapping.cornerIDs { if try work.equal(id, corner) { inCorner = true; break } }
                }
                guard inCorner else { continue }
                for name in mapping.logicalNames { guard try contains(name, facts: facts) else { throw .mappingMismatch } }
                for name in mapping.physicalNames { guard try contains(name, facts: facts) else { throw .mappingMismatch } }
                for layerID in mapping.layerIDs {
                    var layer: PDKLayerDefinition?
                    for candidate in manifest.layers { if try work.equal(candidate.layerID, layerID) { layer = candidate; break } }
                    guard let layer else { throw .mappingMismatch }
                    var found = false
                    for fact in facts.mappings {
                        try work.step()
                        if try work.equal(fact.name, layer.name), fact.layerNumber == layer.number, fact.layerPurpose == layer.purpose { found = true; break }
                    }
                    guard found else { throw .mappingMismatch }
                }
                for deviceID in mapping.deviceIDs {
                    var device: PDKDeviceDefinition?
                    for candidate in manifest.devices { if try work.equal(candidate.deviceID, deviceID) { device = candidate; break } }
                    guard let device else { throw .mappingMismatch }
                    var found = false
                    for fact in facts.mappings {
                        guard try work.equal(fact.name, device.modelName), fact.terminals.count == device.terminals.count else { continue }
                        var matches = true
                        for index in fact.terminals.indices {
                            try work.step()
                            if device.terminals[index].order != index { matches = false; break }
                            if try !work.equal(fact.terminals[index], device.terminals[index].name) { matches = false; break }
                        }
                        if matches { found = true; break }
                    }
                    guard found else { throw .mappingMismatch }
                }
            }
        }
    }
    private func contains(_ name: String, facts: PDKProfileSourceFacts) throws(PDKProfileAdmissionError) -> Bool {
        for fact in facts.mappings { if try work.equal(fact.name, name) { return true } }; return false
    }
}
