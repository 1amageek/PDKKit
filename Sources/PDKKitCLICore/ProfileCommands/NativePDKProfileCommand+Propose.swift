import CircuiteFoundation
import PDKCore
import PDKProfileAdmission
import PDKSourceCapture
import PDKSpiceProfileInspection

extension NativePDKProfileCommand {
    func propose(availability: PDKProfileCLIAvailability, owners: inout PDKProfileCommandOwners,
                 work: PDKProfileCommandWork) async throws {
        guard let document = owners.authoring, let availabilityDocument = owners.availability else {
            throw PDKProfileCommandError.invalidArguments
        }
        let authoring = document.value
        guard try work.equal(authoring.inspectionPolicyIdentity, availability.inspectionPolicyIdentity) else {
            throw PDKProfileCommandError.invalidArguments
        }
        let manifest = try await loadManifest(availability: availability, work: work)
        owners.manifest = manifest
        let count = authoring.candidateSources.count
        owners.reservations.append(try work.reserve(CapturedPDKSource.self, count: count))
        owners.reservations.append(try work.reserve(PDKProfileSource.self, count: count))
        owners.captures.reserveCapacity(count); owners.sources.reserveCapacity(count)
        for index in authoring.candidateSources.indices {
            try work.step()
            let candidate = authoring.candidateSources[index]
            guard let binding = candidate.bindings.first else { throw PDKProfileCommandError.invalidArguments }
            let authorized = try root(binding.rootID, availability: availability, work: work)
            // Operational documents cannot silently override an existing source/route authorization.
            for alias in candidate.bindings {
                for existing in availability.sources {
                    if try work.equal(alias.logicalRoute, existing.logicalRoute) {
                        try work.step()
                        guard try work.equal(alias.sourceKey, existing.sourceKey), alias.rootID == existing.rootID,
                              try samePath(alias.relativePath, existing.relativePath, work: work), alias.budget == existing.budget else {
                            throw PDKProfileCommandError.invalidArguments
                        }
                    }
                }
            }
            var captured: CapturedPDKSource?
            for prior in 0..<index {
                try work.step()
                guard let known = authoring.candidateSources[prior].bindings.first,
                      known.rootID == binding.rootID, known.budget == binding.budget,
                      try samePath(known.relativePath, binding.relativePath, work: work) else { continue }
                let original = owners.captures[prior]
                let reference = ArtifactReference(id: original.reference.id, descriptor: candidate.descriptor)
                captured = try original.rebinding(reference: reference, resources: work.resources)
                break
            }
            if captured == nil {
                captured = try await discovery.discover(descriptor: candidate.descriptor, rootURL: authorized.rootURL,
                    rootID: binding.rootID, relativePath: binding.relativePath, budget: binding.budget, resources: work.resources)
            }
            guard let captured else { throw PDKProfileCommandError.invalidArguments }
            owners.captures.append(captured)
            owners.sources.append(try .init(sourceKey: candidate.sourceKey, assetID: candidate.assetID,
                reference: captured.reference, logicalRoutes: candidate.logicalRoutes, resources: work.resources))
        }
        // Core alone owns catalog/corner selection; no Definition or expected dependency graph exists yet.
        let catalog = try PDKProfileCatalogSelection(manifest: manifest.manifest, manifestReference: manifest.reference,
            requiredCornerIDs: authoring.requiredCornerIDs, requirements: authoring.requirements,
            sources: owners.sources, resources: work.resources)
        owners.catalog = catalog
        let initial = try LocalPDKSpiceCandidateDiscoverer(policyIdentity: authoring.inspectionPolicyIdentity)
            .initialPreprocessingIdentity(resources: work.resources)
        owners.initialIdentity = initial
        var spiceCount = 0
        for candidate in authoring.candidateSources { try work.step(); if candidate.descriptor.format == .spice { spiceCount += 1 } }
        if spiceCount > 0 {
            owners.reservations.append(try work.reserve(PDKSpiceCandidateBinding.self, count: spiceCount))
            owners.spiceBindings.reserveCapacity(spiceCount)
        }
        for candidate in authoring.candidateSources {
            try work.step()
            guard candidate.descriptor.format == .spice, let binding = candidate.bindings.first else { continue }
            owners.spiceBindings.append(.init(sourceKey: candidate.sourceKey, assetID: candidate.assetID,
                logicalRoutes: candidate.logicalRoutes, rootID: binding.rootID, relativePath: binding.relativePath,
                budget: binding.budget, descriptor: candidate.descriptor))
        }
        var contextCapacity = catalog.mandatorySupportSourceKeys.count
        for selection in catalog.selections {
            try work.step()
            let (next, overflow) = contextCapacity.addingReportingOverflow(selection.sourceKeys.count)
            guard !overflow else { throw PDKAdmissionResourceError.arithmeticOverflow(.temporaryBytes) }; contextCapacity = next
        }
        let contextsLease = try work.reserve(PDKProfileSourceContext.self, count: contextCapacity, dimension: .temporaryBytes)
        defer { withExtendedLifetime(contextsLease) {} }
        var contexts: [PDKProfileSourceContext] = []; contexts.reserveCapacity(contextCapacity)
        for selection in catalog.selections {
            for key in selection.sourceKeys {
                try work.step()
                let context = PDKProfileSourceContext(sourceKey: key, selectedSection: selection.selectedSection,
                    preprocessingIdentity: initial.identity, cornerID: selection.cornerID)
                var known = false
                for prior in contexts {
                    if try work.equal(prior.sourceKey, context.sourceKey),
                       try optionalEqual(prior.selectedSection, context.selectedSection, work: work),
                       try optionalEqual(prior.cornerID, context.cornerID, work: work) { known = true; break }
                }
                if !known { contexts.append(context) }
            }
        }
        for key in catalog.mandatorySupportSourceKeys {
            try work.step()
            contexts.append(.init(sourceKey: key, selectedSection: nil, preprocessingIdentity: initial.identity))
        }
        var entryCount = 0
        for context in contexts {
            let source = try source(context.sourceKey, sources: owners.sources, work: work)
            try work.step()
            if source.reference.descriptor.format == .spice { entryCount += 1 }
            else if source.reference.descriptor.format != .json { throw PDKProfileCommandError.unsupportedFormat }
        }
        if entryCount > 0 {
            owners.reservations.append(try work.reserve(PDKSpiceCandidateEntry.self, count: entryCount))
            owners.entries.reserveCapacity(entryCount)
        }
        for context in contexts {
            let source = try source(context.sourceKey, sources: owners.sources, work: work)
            guard source.reference.descriptor.format == .spice, let route = source.logicalRoutes.first else { continue }
            try work.step()
            owners.entries.append(.init(sourceKey: source.sourceKey, logicalRoute: route, selectedSection: context.selectedSection))
        }
        // The existential's concrete pool storage is admitted before boxing; copies share its immutable buffer.
        let poolLease = try work.reserve(PDKProfileCapturedCandidateDiscovery.self, count: 1, dimension: .temporaryBytes)
        defer { withExtendedLifetime(poolLease) {} }
        let pool = PDKProfileCapturedCandidateDiscovery(authoring: document, availability: availabilityDocument, captures: owners.captures)
        let grammar = LocalPDKSpiceCandidateDiscoverer(policyIdentity: authoring.inspectionPolicyIdentity, sourceDiscovery: pool)
        if !owners.entries.isEmpty {
            owners.graph = try await grammar.discover(.init(roots: availability.roots, sources: owners.spiceBindings,
                entries: owners.entries, orderedSearchRoutes: authoring.orderedSearchRoutes), resources: work.resources)
            if let graph = owners.graph {
                guard try work.equal(graph.initialPreprocessingIdentity, initial.identity) else { throw PDKProfileCommandError.invalidArguments }
                for observed in graph.sources {
                    let expected = try source(observed.source.sourceKey, sources: owners.sources, work: work)
                    guard try sameReference(expected.reference, observed.source.reference, work: work) else {
                        throw PDKProfileCommandError.invalidArguments
                    }
                }
            }
        }
        let definition = try PDKProfileDefinition(profileID: authoring.profileID, manifestReference: manifest.reference,
            processID: manifest.manifest.processID, version: manifest.manifest.version, requiredCornerIDs: authoring.requiredCornerIDs,
            requirements: authoring.requirements, sources: owners.sources, orderedSearchRoutes: authoring.orderedSearchRoutes,
            dependencies: owners.graph?.dependencies ?? [], inspectionPolicyIdentity: authoring.inspectionPolicyIdentity,
            initialPreprocessingIdentity: initial.identity, resources: work.resources)
        owners.definition = definition
        owners.plan = try LocalPDKProfilePlanner().plan(.init(definition: definition, manifest: manifest.manifest,
            manifestReference: manifest.reference, resources: work.resources))
        try work.resources.check()
    }

    private func source(_ key: String, sources: [PDKProfileSource], work: PDKProfileCommandWork) throws -> PDKProfileSource {
        for source in sources { if try work.equal(source.sourceKey, key) { return source } }
        throw PDKProfileCommandError.invalidArguments
    }
    private func optionalEqual(_ a: String?, _ b: String?, work: PDKProfileCommandWork) throws -> Bool {
        try work.step()
        switch (a, b) { case (nil, nil): return true; case (let a?, let b?): return try work.equal(a, b); default: return false }
    }
    private func samePath(_ a: ArtifactRelativePath, _ b: ArtifactRelativePath, work: PDKProfileCommandWork) throws -> Bool {
        try work.step()
        guard a.segments.count == b.segments.count else { return false }
        for index in a.segments.indices { if try !work.equal(a.segments[index], b.segments[index]) { return false } }
        return true
    }
}
