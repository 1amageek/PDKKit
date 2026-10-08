import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFileSystem
import PDKCore
import PDKDiscovery
import PDKProfileAdmission
import PDKSourceCapture

public struct NativePDKProfileCLIInputLoader: PDKProfileCLIInputLoading {
    private let roots: any PDKSourceRootOpening
    private let digester: any ContentDigesting
    private let bootstrap: any PDKBudgetBootstrapDecoding
    private let capture: any PDKBoundedLocalSourceCapturing
    private let decoder: NativePDKBoundedDocumentDecoder
    public init(roots: any PDKSourceRootOpening = FoundationPDKSourceRootOpener(),
                digester: any ContentDigesting = SHA256ContentDigester(),
                bootstrap: any PDKBudgetBootstrapDecoding = NativePDKBudgetBootstrapDecoder(),
                capture: any PDKBoundedLocalSourceCapturing = LocalPDKBoundedSourceCapturer()) {
        self.roots = roots; self.digester = digester; self.bootstrap = bootstrap
        self.capture = capture; self.decoder = NativePDKBoundedDocumentDecoder()
    }
    public func loadBudget(root: PDKProfileAuthorizedRoot, relativePath: ArtifactRelativePath,
                           policy: PDKBudgetBootstrapPolicy, accessBudget: ArtifactAccessBudget)
        async throws(PDKProfileCLIInputError) -> PDKLoadedBudgetBootstrap {
        guard accessBudget.maximumTotalByteCount == policy.maximumByteCount,
              accessBudget.maximumPageByteCount == policy.maximumByteCount else { throw .invalidBootstrapPolicy }
        // The fixed Foundation reader caps native data pages at one MiB. Larger
        // parser policies cannot establish this file leaf's single-buffer contract.
        guard policy.maximumByteCount <= 1_048_576 else { throw .unsupportedSinglePageAcquisition }
        let control = try PDKBudgetAcquisitionControl(budget: accessBudget, path: relativePath)
        var rootLease: (any ArtifactSourceRetention)?
        do { rootLease = try control.retain(.openResources(1)) }
        catch { throw .discovery(.control(error)) }
        defer { withExtendedLifetime(rootLease) {} }
        let capability: any PDKSourceDiscoveryRoot
        do { capability = try roots.open(rootID: root.rootID, directoryURL: root.rootURL, digester: digester) }
        catch { throw .root(error) }
        let outcome: Result<ArtifactDiscoveredSource, PDKProfileCLIInputError>
        do {
            outcome = .success(try await capability.discover(.init(rootID: root.rootID, relativePath: relativePath,
                descriptor: .init(role: .input, kind: .request, format: .json), budget: accessBudget), control: control))
        } catch { outcome = .failure(.discovery(error)) }
        do { try await capability.shutdown() }
        catch {
            if case .failure(let primary) = outcome { throw .cleanup(primary: primary, cleanup: error) }
            throw .root(error)
        }
        rootLease = nil
        let source: ArtifactDiscoveredSource
        switch outcome { case .success(let value): source = value; case .failure(let error): throw error }
        guard source.work.pageCount <= 1, source.byteCount <= policy.maximumByteCount else {
            throw .unsupportedSinglePageAcquisition
        }
        let parsed: PDKBudgetBootstrapResult
        do {
            parsed = try source.withAccountedUnsafeBytes { pointer in
                // Foundation owns the sole initialized UInt8 page for this borrow.
                // The span and pointer do not escape the closure; no copy is admitted.
                guard let start = pointer.bindMemory(to: UInt8.self).baseAddress else {
                    throw PDKBudgetBootstrapError.malformedInput
                }
                return try bootstrap.decode(Span(_unsafeStart: start, count: pointer.count), policy: policy)
            }
        } catch let error as PDKBudgetBootstrapError { throw .bootstrap(error) }
        catch let error as ArtifactSourceDiscoveryError { throw .discovery(error) }
        catch { throw .invalidBinding }
        do { try control.check() } catch { throw .discovery(.control(error)) }
        return PDKLoadedBudgetBootstrap(parsed: parsed, source: source, acquisition: control.snapshot())
    }
    public func loadAvailability(binding: PDKProfileExactBinding, root: PDKProfileAuthorizedRoot,
                                 resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileCLIInputError) -> PDKDecodedDocument<PDKProfileCLIAvailability> {
        try await load(PDKProfileCLIAvailability.self, descriptor: PDKProfileCLIAvailability.artifactDescriptor,
            binding: binding, root: root, resources: resources)
    }
    public func loadAuthoring(binding: PDKProfileExactBinding, root: PDKProfileAuthorizedRoot,
                              resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileCLIInputError) -> PDKDecodedDocument<PDKProfileCLIAuthoring> {
        try await load(PDKProfileCLIAuthoring.self, descriptor: PDKProfileCLIAuthoring.artifactDescriptor,
            binding: binding, root: root, resources: resources)
    }
    private func load<Value: Decodable & Sendable>(_ type: Value.Type, descriptor: ArtifactDescriptor, binding: PDKProfileExactBinding,
        root: PDKProfileAuthorizedRoot, resources: any PDKAdmissionResourceAccounting)
        async throws(PDKProfileCLIInputError) -> PDKDecodedDocument<Value> {
        do { try resources.check() } catch { throw .resource(error) }
        guard binding.rootID == root.rootID, binding.reference.descriptor == descriptor else { throw .invalidBinding }
        let source: CapturedPDKSource
        do { source = try await capture.capture(reference: binding.reference, rootURL: root.rootURL,
            rootID: root.rootID, relativePath: binding.relativePath, budget: binding.budget, resources: resources) }
        catch { throw .source(error) }
        do { return try decoder.decodeAudited(type, source: source, accounting: resources,
            rejectUnknownFields: true, validate: { _ in }) }
        catch { throw .decode(error) }
    }
}
