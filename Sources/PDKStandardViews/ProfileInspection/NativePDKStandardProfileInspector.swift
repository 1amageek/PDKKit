import CircuiteFoundation
import PDKCore
import PDKDiscovery
import PDKProfileAdmission
import TechIR

public struct NativePDKStandardProfileInspector: PDKProfileSourceInspecting {
    public static let technologyParserIdentity = "pdkkit.irtechlibrary-json.v1"
    public static let unsupportedParserIdentity = "pdkkit.standard-profile.unsupported.v1"
    private let format: ArtifactFormat
    private let policyIdentity: String
    private let technologyDecoder: any PDKStandardTechnologyDecoding

    public init(format: ArtifactFormat, policyIdentity: String,
                technologyDecoder: any PDKStandardTechnologyDecoding = NativePDKStandardTechnologyDecoder()) {
        self.format = format; self.policyIdentity = policyIdentity; self.technologyDecoder = technologyDecoder
    }

    public func inspect(_ request: PDKProfileSourceInspectionRequest, dependencies: any PDKProfileDependencyResolving,
                        resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileInspectionError) -> PDKProfileSourceFacts {
        let work = PDKStandardProfileWork(resources: resources)
        try work.check()
        guard try work.equal(request.input.reference.descriptor.format.rawValue, format.rawValue) else { throw .unsupportedFormat }
        guard try work.equal(request.inspectionPolicyIdentity, policyIdentity) else { throw .invalidFacts }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Opaque standard/deck/extraction codecs
        // have no whole-invocation accounting/closure contract on this production
        // profile path. Refuse until each format owner supplies and verifies it;
        // structural parse success must never satisfy profile admission.
        guard format == .json else { throw .resource(.unsupportedBudgetCapability("Standard profile codec accounting is unavailable")) }
        guard request.view == nil || request.view == .layerMap || request.view == .other,
              request.input.context.selectedSection == nil else { throw .unsupportedSemantics }
        for kind in request.demandedFactKinds {
            try work.charge(.parserWork)
            if try work.equal(kind, "layers") { continue }
            if try work.equal(kind, "vias") { continue }
            if try work.equal(kind, "sites") { continue }
            guard try work.equal(kind, "dependencyClosure") else { throw .unsupportedSemantics }
        }
        let decoded: PDKDecodedDocument<IRTechLibrary>
        do { decoded = try technologyDecoder.decodeTechnology(request.input.capture, resources: resources) }
        catch {
            switch error {
            case .resource(let error): throw .resource(error)
            case .unsupportedValue: throw .unsupportedSemantics
            default: throw .malformedSource
            }
        }
        defer { withExtendedLifetime(decoded) {} }
        guard let sourceReference = decoded.sourceReference, try work.equal(sourceReference, request.input.reference) else { throw .invalidFacts }
        let library = decoded.value
        let (first, firstOverflow) = library.layers.count.addingReportingOverflow(library.vias.count)
        let (count, secondOverflow) = first.addingReportingOverflow(library.sites.count)
        guard !firstOverflow, !secondOverflow else { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        let mappingOwner = try work.capacity(PDKProfileMappingFact.self, count: count)
        let coverageOwner = try work.capacity(PDKProfileSourceCoverage.self, count: 1)
        defer { withExtendedLifetime(mappingOwner) {}; withExtendedLifetime(coverageOwner) {} }
        var mappings: [PDKProfileMappingFact] = []; mappings.reserveCapacity(count)
        for layer in library.layers {
            try work.charge(.parserWork); guard !layer.name.isEmpty else { throw .malformedSource }
            mappings.append(.init(input: request.input, factKind: "layers", name: layer.name, layerNumber: layer.gdsLayer))
        }
        for via in library.vias {
            try work.charge(.parserWork); guard !via.name.isEmpty else { throw .malformedSource }
            mappings.append(.init(input: request.input, factKind: "vias", name: via.name))
        }
        for site in library.sites {
            try work.charge(.parserWork); guard !site.name.isEmpty else { throw .malformedSource }
            mappings.append(.init(input: request.input, factKind: "sites", name: site.name))
        }
        let coverage = [PDKProfileSourceCoverage(input: request.input, meaning: .leaf, observedSection: nil,
            evidenceIdentity: "pdkkit.irtechlibrary-json.data-only.v1", activeDependencies: [], inactiveStatementOffsets: [])]
        let facts = try PDKProfileSourceFacts(input: request.input, parserIdentity: Self.technologyParserIdentity,
            policyIdentity: policyIdentity, mappings: mappings, pvt: [], temperatures: [], coverage: coverage,
            events: [], unsupportedFactKinds: [], lostFactKinds: [], resources: resources)
        try work.check(); return facts
    }
}
