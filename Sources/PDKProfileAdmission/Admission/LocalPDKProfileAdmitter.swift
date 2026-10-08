import CircuiteFoundation
import PDKCore
import PDKDiscovery
import PDKSourceCapture

public struct LocalPDKProfileAdmitter: PDKProfileAdmitting {
    private let capture: any PDKBoundedLocalSourceCapturing
    private let decoder: any PDKBoundedDocumentDecoding
    private let inspectors: [PDKProfileInspectorRegistration]
    private let clock: any PDKAdmissionExecutionClock
    public init(inspectors: [PDKProfileInspectorRegistration],
                capture: any PDKBoundedLocalSourceCapturing = LocalPDKBoundedSourceCapturer(),
                decoder: any PDKBoundedDocumentDecoding = NativePDKBoundedDocumentDecoder(),
                clock: any PDKAdmissionExecutionClock = SystemPDKAdmissionExecutionClock()) {
        self.inspectors = inspectors; self.capture = capture; self.decoder = decoder; self.clock = clock
    }
    public func admit(_ request: PDKProfileAdmissionRequest) async throws(PDKProfileAdmissionError) -> AdmittedPDKProfile {
        let resources = LocalPDKAdmissionResources(budget: request.budget, clock: clock)
        defer { resources.close() }
        let work = PDKAdmissionWork(resources: resources)
        let availability = PDKProfileAvailability(request: request, work: work)
        try availability.validate()
        try registrations(work)
        let registry = PDKProfileSourceRegistry(capture: capture, resources: resources)
        let definitionRoot = try availability.root(request.definition.rootID)
        let definitionSource = try await registry.acquire(reference: request.definition.reference,
            rootURL: definitionRoot.rootURL, rootID: request.definition.rootID,
            relativePath: request.definition.relativePath, budget: request.definition.budget)
        let document: PDKDecodedDocument<PDKProfileDefinition>
        do { document = try decoder.decodeDefinition(definitionSource, accounting: resources) }
        catch { throw .definition(error) }
        guard let reference = document.sourceReference, try work.equal(reference, definitionSource.reference) else { throw .providerIdentity }
        do { return try await finish(request, document: document, definitionSource: definitionSource,
            registry: registry, resources: resources, work: work, availability: availability) }
        catch {
            if error.requiresDefinitionOwner {
                throw .retained(.init(reason: error, document: document, source: definitionSource))
            }
            throw error
        }
    }
    private func finish(_ request: PDKProfileAdmissionRequest, document: PDKDecodedDocument<PDKProfileDefinition>,
        definitionSource: CapturedPDKSource, registry: PDKProfileSourceRegistry, resources: LocalPDKAdmissionResources,
        work: PDKAdmissionWork, availability: PDKProfileAvailability)
        async throws(PDKProfileAdmissionError) -> AdmittedPDKProfile {
        let definition = document.value
        guard try work.equal(definition.inspectionPolicyIdentity, request.inspectionPolicyIdentity),
              try work.equal(definition.manifestReference, request.manifest.reference) else { throw .policyMismatch }
        for binding in request.sources {
            try work.step()
            var found = false
            for source in definition.sources {
                if try work.equal(binding.sourceKey, source.sourceKey) { _ = try availability.source(source); found = true; break }
            }
            guard found else { throw .missingBinding }
        }
        let manifestRoot = try availability.root(request.manifest.rootID)
        let manifest: PDKBoundedLoadedManifest
        do {
            manifest = try await LocalPDKBoundedManifestLoader(capture: PDKRegistrySourceCapturer(registry: registry), decoder: decoder)
                .loadExact(reference: definition.manifestReference, rootURL: manifestRoot.rootURL,
                    rootID: request.manifest.rootID, relativePath: request.manifest.relativePath,
                    budget: request.manifest.budget, resources: resources)
        } catch { throw .manifest(error) }
        let plan = try LocalPDKProfilePlanner().plan(.init(definition: definition, manifest: manifest.manifest,
            manifestReference: manifest.reference, resources: resources))
        let claim: PDKProfileClaim
        do { claim = try PDKProfileClaim(definitionReference: request.definition.reference, plan: plan, resources: resources) }
        catch { throw .selection(error) }
        let authority = PDKProfileInputAuthority(definition: document, source: definitionSource, resources: resources)
        let resolver = PDKProfileInvocationResolver(authority: authority, availability: availability,
            registry: registry, expected: claim.dependencies)
        var facts = PDKAdmissionCollection<PDKProfileSourceFacts>()
        var roots = PDKAdmissionCollection<PDKProfileRootOccurrence>()
        let checking = PDKProfileFactChecking(work: work)
        for selection in plan.selections {
            for sourceKey in selection.sourceKeys {
                let context = PDKProfileSourceContext(sourceKey: sourceKey, selectedSection: selection.selectedSection,
                    preprocessingIdentity: definition.inspectionPolicyIdentity, cornerID: selection.cornerID)
                var existing: PDKProfileSourceFacts?
                for candidate in facts { if try work.equal(candidate.input.context, context) { existing = candidate; break } }
                let selectedFacts: PDKProfileSourceFacts
                if let existing { selectedFacts = existing }
                else {
                    let source = try source(sourceKey, definition: definition, work: work)
                    let input = try await resolver.root(source: source, context: context)
                    let demand = try demands(context, plan: plan, work: work)
                    let lease = demand.1
                    defer { withExtendedLifetime(lease) {} }
                    let corner = try corner(selection.cornerID, plan: plan, work: work)
                    selectedFacts = try await inspect(input, requirementID: selection.requirementID,
                        view: try requirement(selection.requirementID, definition: definition, work: work).view,
                        corner: corner, demands: demand.0, resolver: resolver, policy: definition.inspectionPolicyIdentity, work: work)
                    try facts.append(selectedFacts, work: work)
                }
                try checking.selected(selection, sourceKey: sourceKey, manifest: manifest.manifest, facts: selectedFacts, plan: plan)
                try roots.append(.init(nodeID: selectedFacts.input.nodeID, selection: selection, isMandatorySupport: false), work: work)
            }
        }
        for key in plan.mandatorySupportSourceKeys {
            let source = try source(key, definition: definition, work: work)
            let context = PDKProfileSourceContext(sourceKey: key, selectedSection: nil,
                preprocessingIdentity: definition.inspectionPolicyIdentity)
            let input = try await resolver.root(source: source, context: context)
            let support = try await inspect(input, requirementID: nil, view: nil, corner: nil,
                demands: [], resolver: resolver, policy: definition.inspectionPolicyIdentity, work: work)
            try facts.append(support, work: work)
            try roots.append(.init(nodeID: input.nodeID, selection: nil, isMandatorySupport: true), work: work)
        }
        let graph = try await resolver.freeze()
        // Only checked observed sources can satisfy the canonical expected closure.
        for source in claim.sourceClosure {
            var found = false
            for input in graph.0 {
                if try work.equal(input.sourceKey, source.sourceKey), try work.equal(input.reference, source.reference) { found = true; break }
            }
            guard found else { throw .missingCoverage }
        }
        try work.check()
        return try AdmittedPDKProfile(claim: claim, inputs: graph.0, facts: facts, dependencies: graph.1,
            roots: roots, authority: authority, manifest: manifest, work: work)
    }
    private func registrations(_ work: PDKAdmissionWork) throws(PDKProfileAdmissionError) {
        for index in inspectors.indices {
            try work.step()
            for prior in inspectors[..<index] {
                if try work.equal(prior.format.rawValue, inspectors[index].format.rawValue),
                   try work.equal(prior.policyIdentity, inspectors[index].policyIdentity) { throw .policyMismatch }
            }
        }
    }
    private func inspect(_ input: PDKProfileSourceInput, requirementID: String?, view: PDKViewKind?,
        corner: PDKProfileCorner?, demands: [String], resolver: PDKProfileInvocationResolver,
        policy: String, work: PDKAdmissionWork) async throws(PDKProfileAdmissionError) -> PDKProfileSourceFacts {
        var selected: PDKProfileInspectorRegistration?
        for registration in inspectors {
            if try work.equal(registration.format.rawValue, input.reference.descriptor.format.rawValue),
               try work.equal(registration.policyIdentity, policy) { selected = registration; break }
        }
        guard let selected else { throw .inspection(.unsupportedFormat) }
        let first = await resolver.eventCount()
        let result: PDKProfileSourceFacts
        do { result = try await selected.inspector.inspect(.init(input: input, requirementID: requirementID,
            view: view, corner: corner, demandedFactKinds: demands, policy: policy), dependencies: resolver, resources: work.resources) }
        catch { try await resolver.checkFailure(); throw .inspection(error) }
        try work.check()
        try await resolver.validateFacts(result, root: input, firstEvent: first)
        let checking = PDKProfileFactChecking(work: work)
        try checking.identity(result, registration: selected, policy: policy); try checking.demanded(demands, facts: result)
        return result
    }
    private func source(_ key: String, definition: PDKProfileDefinition, work: PDKAdmissionWork) throws(PDKProfileAdmissionError) -> PDKProfileSource {
        for source in definition.sources { if try work.equal(source.sourceKey, key) { return source } }; throw .missingBinding
    }
    private func requirement(_ key: String, definition: PDKProfileDefinition, work: PDKAdmissionWork) throws(PDKProfileAdmissionError) -> PDKViewRequirement {
        for requirement in definition.requirements { if try work.equal(requirement.requirementID, key) { return requirement } }; throw .missingCoverage
    }
    private func corner(_ id: String?, plan: PDKProfilePlan, work: PDKAdmissionWork) throws(PDKProfileAdmissionError) -> PDKProfileCorner? {
        guard let id else { return nil }
        for corner in plan.corners { if try work.equal(corner.cornerID, id) { return corner } }; throw .pvtMismatch
    }
    private func demands(_ context: PDKProfileSourceContext, plan: PDKProfilePlan, work: PDKAdmissionWork)
        throws(PDKProfileAdmissionError) -> ([String], PDKAdmissionReservation?) {
        var capacity = 0
        for requirement in plan.definition.requirements {
            let (next, overflow) = capacity.addingReportingOverflow(requirement.demandedFactKinds.count)
            guard !overflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }; capacity = next; try work.step()
        }
        let lease = try work.capacity(String.self, capacity, dimension: .temporaryBytes)
        var result: [String] = []; result.reserveCapacity(capacity)
        for selection in plan.selections {
            guard try work.equal(selection.cornerID, context.cornerID),
                  try work.equal(selection.selectedSection, context.selectedSection) else { continue }
            var bound = false
            for key in selection.sourceKeys { if try work.equal(key, context.sourceKey) { bound = true; break } }
            guard bound else { continue }
            let requirement = try requirement(selection.requirementID, definition: plan.definition, work: work)
            for kind in requirement.demandedFactKinds {
                var found = false
                for prior in result { if try work.equal(prior, kind) { found = true; break } }
                if !found { try work.step(); result.append(kind) }
            }
        }
        return (result, lease)
    }
}
