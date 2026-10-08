import CoreSpiceIO
import PDKCore
import PDKProfileAdmission

/// Native exact-source inspection using the ordinary bounded CoreSpice grammar.
public struct LocalPDKSpiceProfileInspector: PDKProfileSourceInspecting {
    public static let parserIdentity = "core-spice.profile-grammar.v1"
    private let policyIdentity: String
    private let configuration: ParserConfiguration
    private let maximumPageByteCount: UInt64

    public init(policyIdentity: String, configuration: ParserConfiguration = .init(resolveIncludes: true),
                maximumPageByteCount: UInt64 = 4096) {
        self.policyIdentity = policyIdentity; self.configuration = configuration
        self.maximumPageByteCount = maximumPageByteCount
    }
    public func inspect(_ request: PDKProfileSourceInspectionRequest, dependencies: any PDKProfileDependencyResolving,
                        resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileInspectionError) -> PDKProfileSourceFacts {
        let bridge = PDKSpiceResourceBridge(resources: resources)
        var resolver: PDKSpiceOccurrenceResolver?
        do {
            try bridge.checkCancellation()
            guard request.input.reference.descriptor.format == .spice else { throw PDKProfileInspectionError.unsupportedFormat }
            guard try bridge.equal(policyIdentity, request.inspectionPolicyIdentity), configuration.resolveIncludes,
                  maximumPageByteCount > 0, Int(exactly: maximumPageByteCount) != nil else {
                throw PDKProfileInspectionError.invalidFacts
            }
            for demand in request.demandedFactKinds {
                try bridge.charge(.tokens, units: 1)
                if try bridge.equal(demand, "sourcePVT") { throw PDKProfileInspectionError.unsupportedSemantics }
            }
            let environment = try SPICEPreprocessingEnvironment.empty(policyIdentity: policyIdentity,
                configuration: configuration, resources: bridge, maximumPageByteCount: maximumPageByteCount)
            guard try bridge.equal(request.input.context.preprocessingIdentity, environment.identity) else {
                throw PDKProfileInspectionError.invalidFacts
            }
            let invocation = try PDKSpiceOccurrenceResolver.admit(dependencies: dependencies, bridge: bridge,
                page: maximumPageByteCount)
            resolver = invocation
            let document = try await invocation.register(request.input)
            let parsed = try await SPICEParser().parseProfile(document: document, configuration: configuration,
                environment: environment, resolver: invocation, resources: bridge)
            defer { withExtendedLifetime((parsed, document, environment, invocation)) {} }
            var projection = PDKSpiceFactProjection(bridge: bridge, resolver: invocation)
            let facts = try await projection.project(parsed.netlist, request: request, policy: policyIdentity)
            try bridge.checkCancellation(); return facts
        } catch let failure as SPICEProfileParseFailure {
            defer { withExtendedLifetime(failure) {} }
            do {
                let location = failure.diagnostic.location
                let entry: PDKSpiceOccurrenceResolver.Entry?
                if let resolver, let location { entry = try await resolver.entry(file: location.file) }
                else { entry = nil }
                let diagnostic = try PDKProfileSyntaxDiagnostic(message: failure.diagnostic.message,
                    sourceKey: entry?.input.sourceKey, file: location?.file, line: location?.line,
                    column: location?.column, resources: resources)
                throw PDKProfileInspectionError.syntax(diagnostic)
            } catch let error as PDKProfileInspectionError { throw error }
            catch let error as PDKAdmissionResourceError { throw .resource(error) }
            catch { throw .invalidFacts }
        } catch let error as PDKProfileInspectionError { throw error }
        catch let error as PDKAdmissionResourceError { throw .resource(error) }
        catch SPICEBoundedSourceError.unsupportedBudgetCapability(let capability) {
            throw .resource(.unsupportedBudgetCapability(capability))
        } catch {
            // Exact resolver causes remain recorded by the admission resolver and take precedence.
            throw .unsupportedSemantics
        }
    }
}
