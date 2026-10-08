import CoreSpiceIO
import PDKCore
import PDKProfileAdmission
import PDKSourceCapture

public struct LocalPDKSpiceCandidateDiscoverer: PDKSpiceCandidateDiscovering {
    private let policyIdentity: String
    private let configuration: ParserConfiguration
    private let maximumPageByteCount: UInt64
    private let sourceDiscovery: any PDKLocalSourceDiscovering
    public init(policyIdentity: String, configuration: ParserConfiguration = .init(resolveIncludes: true),
                maximumPageByteCount: UInt64 = 4096,
                sourceDiscovery: any PDKLocalSourceDiscovering = LocalPDKBoundedSourceCapturer()) {
        self.policyIdentity = policyIdentity; self.configuration = configuration
        self.maximumPageByteCount = maximumPageByteCount; self.sourceDiscovery = sourceDiscovery
    }
    public func discover(_ request: PDKSpiceCandidateDiscoveryRequest,
                         resources: any PDKAdmissionResourceAccounting)
        async throws(PDKSpiceCandidateDiscoveryError) -> PDKSpiceCandidateGraph {
        let bridge = PDKSpiceResourceBridge(resources: resources)
        var resolver: PDKSpiceCandidateResolver?
        do {
            try bridge.checkCancellation()
            guard !policyIdentity.isEmpty, configuration.resolveIncludes, configuration.maxIncludeDepth >= 0,
                  maximumPageByteCount > 0, Int(exactly: maximumPageByteCount) != nil else {
                throw PDKSpiceCandidateDiscoveryError.invalidRequest
            }
            let invocation = try PDKSpiceCandidateResolver.admit(request: request, bridge: bridge,
                page: maximumPageByteCount, discovery: sourceDiscovery)
            resolver = invocation
            try await invocation.validate()
            let environment = try SPICEPreprocessingEnvironment.empty(policyIdentity: policyIdentity,
                configuration: configuration, resources: bridge, maximumPageByteCount: maximumPageByteCount)
            for entry in request.entries {
                let document = try await invocation.root(entry, environment: environment)
                let parsed = try await SPICEParser().parseProfile(document: document, configuration: configuration,
                    environment: environment, resolver: invocation, resources: bridge)
                try await invocation.record(parsed)
            }
            return try await invocation.publish(environment: environment, policyIdentity: policyIdentity)
        } catch let failure as SPICEProfileParseFailure {
            defer { withExtendedLifetime(failure) {} }
            do {
                let location = failure.diagnostic.location
                let sourceKey: String?
                if let resolver, let location { sourceKey = try await resolver.sourceKey(file: location.file) }
                else { sourceKey = nil }
                let diagnostic = try PDKProfileSyntaxDiagnostic(message: failure.diagnostic.message,
                    sourceKey: sourceKey, file: location?.file, line: location?.line,
                    column: location?.column, resources: resources)
                throw PDKSpiceCandidateDiscoveryError.syntax(diagnostic)
            } catch let error as PDKSpiceCandidateDiscoveryError { throw error }
            catch let error as PDKProfileInspectionError {
                if case .resource(let cause) = error { throw .resource(cause) }; throw .invalidRequest
            } catch let error as PDKAdmissionResourceError { throw .resource(error) }
            catch { throw .invalidRequest }
        } catch let error as PDKSpiceCandidateDiscoveryError { throw error }
        catch let error as PDKSourceCaptureError { throw .source(error) }
        catch let error as PDKProfileValueError { throw .value(error) }
        catch let error as PDKAdmissionResourceError { throw .resource(error) }
        catch SPICEBoundedSourceError.unsupportedBudgetCapability(let capability) {
            throw .resource(.unsupportedBudgetCapability(capability))
        } catch SPICESourceStorageError.arithmeticOverflow { throw .resource(.arithmeticOverflow(.temporaryBytes)) }
        catch { throw .unsupportedSemantics }
    }
}
