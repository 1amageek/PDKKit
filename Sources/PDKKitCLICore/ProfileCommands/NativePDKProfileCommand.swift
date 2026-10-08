import CircuiteFoundation
import PDKCore
import PDKDiscovery
import PDKSourceCapture
import PDKProfileAdmission
import PDKSpiceProfileInspection
import PDKStandardViews

public struct NativePDKProfileCommand: PDKProfileCommandExecuting {
    private let input: any PDKProfileCLIInputLoading
    let capture: any PDKBoundedLocalSourceCapturing
    let discovery: any PDKLocalSourceDiscovering
    let decoder: any PDKBoundedDocumentDecoding
    let manifests: any PDKBoundedManifestLoading
    private let encoder: any PDKProfileOutputEncoding
    private let delivery: any PDKProfileOutputDelivering
    private let clock: any PDKAdmissionExecutionClock
    private let bootstrapPolicy: PDKBudgetBootstrapPolicy
    private let bootstrapAccessBudget: ArtifactAccessBudget?

    public init(input: any PDKProfileCLIInputLoading = NativePDKProfileCLIInputLoader(),
                capture: any PDKBoundedLocalSourceCapturing = LocalPDKBoundedSourceCapturer(),
                discovery: any PDKLocalSourceDiscovering = LocalPDKBoundedSourceCapturer(),
                decoder: any PDKBoundedDocumentDecoding = NativePDKBoundedDocumentDecoder(),
                manifests: any PDKBoundedManifestLoading = LocalPDKBoundedManifestLoader(),
                encoder: any PDKProfileOutputEncoding = NativePDKProfileOutputEncoder(),
                delivery: any PDKProfileOutputDelivering = NativePDKProfileOutputDelivery(),
                clock: any PDKAdmissionExecutionClock = SystemPDKAdmissionExecutionClock(),
                bootstrapPolicy: PDKBudgetBootstrapPolicy = .standard,
                bootstrapAccessBudget: ArtifactAccessBudget? = nil) {
        self.input = input; self.capture = capture; self.discovery = discovery; self.decoder = decoder
        self.manifests = manifests; self.encoder = encoder; self.delivery = delivery; self.clock = clock
        self.bootstrapPolicy = bootstrapPolicy; self.bootstrapAccessBudget = bootstrapAccessBudget
    }

    public func execute(arguments: [String], argumentStart: Int = 0,
                        standardOutput: any PDKProfileOutputSink,
                        standardError: any PDKProfileOutputSink) async -> PDKProfileCommandResult {
        let options: PDKProfileCommandOptions
        let bootstrap: PDKLoadedBudgetBootstrap
        do {
            options = try .init(arguments: arguments, start: argumentStart, policy: bootstrapPolicy)
            let native = try PDKSourceCapturePolicy.defaultBudget
            let access = try bootstrapAccessBudget ?? ArtifactAccessBudget(
                maximumPageByteCount: bootstrapPolicy.maximumByteCount,
                maximumTotalByteCount: bootstrapPolicy.maximumByteCount, maximumPageCount: 1,
                maximumWorkUnitCount: native.maximumWorkUnitCount,
                maximumDurationNanoseconds: native.maximumDurationNanoseconds)
            bootstrap = try await input.loadBudget(root: options.root, relativePath: options.budgetPath,
                policy: bootstrapPolicy, accessBudget: access)
        } catch { return Self.bootstrapFailure(.preserving(error), sink: standardError) }

        let resources = LocalPDKAdmissionResources(budget: bootstrap.parsed.budget, clock: clock)
        defer { resources.close() }
        let work = PDKProfileCommandWork(resources: resources)
        var owners = PDKProfileCommandOwners()
        owners.bootstrap = bootstrap
        var completion: PDKProfileOutputCompletion?
        var failure: PDKProfileCommandError?
        var phase = "bootstrap"
        do {
            // The immutable result's concrete slots are admitted before payload ownership grows.
            owners.reservations.append(try work.reserve(PDKProfileCommandOwners.self, count: 1))
            owners.reservations.append(try work.reserve((Int32, PDKOwnedProfileOutput?, Bool,
                PDKProfileCommandError?, PDKProfileOutputError?, PDKProfileOutputError?).self, count: 1))
            completion = try encoder.reserveCompletion(resources: resources, policy: .standard)
            let binding = try options.availability(work: work, budget: resources.budget, reservations: &owners.reservations)
            owners.availabilityBinding = binding
            let availability = try await input.loadAvailability(binding: binding, root: options.root, resources: resources)
            owners.availability = availability; phase = "availability"
            switch options.verb {
            case .propose:
                let binding = try options.authoring(work: work, budget: resources.budget, reservations: &owners.reservations)
                owners.authoringBinding = binding
                owners.authoring = try await input.loadAuthoring(binding: binding, root: options.root, resources: resources)
                phase = "authoring"
                try await propose(availability: availability.value, owners: &owners, work: work)
                phase = "candidate-definition"
            case .plan:
                try await plan(availability: availability.value, owners: &owners, work: work)
                phase = "selection-plan"
            case .admit, .replay:
                if options.verb == .replay {
                    guard let binding = availability.value.claim else { throw PDKProfileCommandError.invalidArguments }
                    let root = try root(binding.rootID, availability: availability.value, work: work)
                    let source = try await capture.capture(reference: binding.reference, rootURL: root.rootURL,
                        rootID: binding.rootID, relativePath: binding.relativePath, budget: binding.budget, resources: resources)
                    owners.claimCapture = source
                    let document = try decoder.decodeClaim(source, accounting: resources)
                    owners.claimDocument = document
                    guard let decodedReference = document.sourceReference,
                          try sameReference(decodedReference, source.reference, work: work) else {
                        throw PDKProfileCommandError.invalidArguments
                    }
                    phase = "retained-claim"
                }
                guard let binding = availability.value.definition else { throw PDKProfileCommandError.invalidArguments }
                if let retained = owners.claimDocument,
                   try !sameReference(retained.value.definitionReference, binding.reference, work: work) {
                    throw PDKProfileCommandError.replayMismatch
                }
                let policy = availability.value.inspectionPolicyIdentity
                let registrationsLease = try work.reserve(PDKProfileInspectorRegistration.self, count: 2, dimension: .temporaryBytes)
                let spiceMetadata = try work.reserve(LocalPDKSpiceProfileInspector.self, count: 1, dimension: .temporaryBytes)
                let jsonMetadata = try work.reserve(NativePDKStandardProfileInspector.self, count: 1, dimension: .temporaryBytes)
                defer { withExtendedLifetime((registrationsLease, spiceMetadata, jsonMetadata)) {} }
                let registrations = try [PDKProfileInspectorRegistration(format: .spice,
                    parserIdentity: LocalPDKSpiceProfileInspector.parserIdentity, policyIdentity: policy,
                    inspector: LocalPDKSpiceProfileInspector(policyIdentity: policy)),
                    PDKStandardProfileInspection.technologyRegistration(policyIdentity: policy)]
                let request = PDKProfileAdmissionRequest(definition: binding, manifest: availability.value.manifest,
                    roots: availability.value.roots, sources: availability.value.sources,
                    budget: resources.budget, inspectionPolicyIdentity: policy)
                owners.admitted = try await LocalPDKProfileAdmitter(inspectors: registrations,
                    capture: capture, decoder: decoder, clock: clock).admit(request, resources: resources)
                phase = "admitted-profile"
                if let retained = owners.claimDocument, let admitted = owners.admitted {
                    guard try retained.value.matchesExactly(admitted.claim, resources: resources) else {
                        throw PDKProfileCommandError.replayMismatch
                    }
                    phase = "replayed-profile"
                }
            }
            try resources.check()
        } catch { failure = .preserving(error) }

        guard let completion else {
            let cause = failure ?? .invalidArguments
            return Self.bootstrapFailure(cause, sink: standardError, owners: owners,
                refusalExitCode: cause.exitCode)
        }
        let envelope = PDKProfileCommandEnvelope(command: options.verb.rawValue, scope: scope(options.verb),
            terminalStatus: failure?.terminalStatus ?? "completed", reason: failure?.code, completedPhase: phase,
            bootstrapReference: bootstrap.reference, bootstrapAcquisition: bootstrap.acquisition,
            definitionReference: owners.admitted?.claim.definitionReference ?? owners.definitionCapture?.reference,
            manifestReference: owners.admitted?.claim.manifestReference ?? owners.manifest?.reference,
            inspectionPolicyIdentity: owners.availability?.value.inspectionPolicyIdentity,
            definition: failure == nil ? owners.definition : nil, plan: failure == nil ? owners.plan : nil,
            claim: failure == nil ? owners.admitted?.claim : nil)
        var output: PDKOwnedProfileOutput?
        do {
            let prepared = try encoder.prepare(envelope, completion: completion)
            let observations = try PDKProfileOutputObservations(snapshot: resources.snapshot(), bootstrap: bootstrap.parsed)
            let completed = try prepared.complete(observations: observations)
            output = completed
            _ = try delivery.deliver(completed, to: failure == nil ? standardOutput : standardError)
            return .init(exitCode: failure?.exitCode ?? 0, output: completed, isStandardError: failure != nil,
                failure: failure, deliveryFailure: nil, owners: owners)
        } catch {
            let cause = PDKProfileCommandError.preserving(error)
            let outputError: PDKProfileOutputError
            if case .output(let error) = cause { outputError = error }
            else if case .resource(let error) = cause { outputError = .resource(error) }
            else { outputError = .codec(error) }
            // Reserved static diagnostics remain deliverable after exhaustion; they never establish success.
            let terminal = completion.terminalOutput
            var terminalFailure: PDKProfileOutputError?
            do {
                let written = try terminal.withBytes { try standardError.write($0) }
                guard written == terminal.byteCount else {
                    throw PDKProfileOutputError.shortWrite(expected: terminal.byteCount, actual: written)
                }
                try standardError.finish()
            } catch let cleanup as PDKProfileOutputSinkError { terminalFailure = .sink(cleanup) }
            catch let cleanup as PDKProfileOutputError { terminalFailure = cleanup }
            catch { terminalFailure = .codec(error) }
            return .init(exitCode: 1, output: output ?? terminal, isStandardError: output == nil,
                failure: failure ?? cause, deliveryFailure: outputError, terminalDeliveryFailure: terminalFailure, owners: owners)
        }
    }

    private func scope(_ verb: PDKProfileCommandOptions.Verb) -> String {
        switch verb { case .propose: "candidate-definition"; case .plan: "selection-plan";
        case .admit: "admitted-profile"; case .replay: "replayed-profile" }
    }
    private static let bootstrapDiagnostic = Array("{\"schemaVersion\":1,\"terminalStatus\":\"failed\",\"reason\":\"profile-bootstrap-refused\"}\n".utf8)
    private static func bootstrapFailure(_ error: PDKProfileCommandError, sink: any PDKProfileOutputSink,
                                         owners: PDKProfileCommandOwners? = nil,
                                         refusalExitCode: Int32 = 1) -> PDKProfileCommandResult {
        var deliveryError: PDKProfileOutputError?
        do {
            let count = try sink.write(bootstrapDiagnostic.span)
            guard count == bootstrapDiagnostic.count else { throw PDKProfileOutputError.shortWrite(expected: bootstrapDiagnostic.count, actual: count) }
            try sink.finish()
        } catch let error as PDKProfileOutputSinkError { deliveryError = .sink(error) }
        catch let error as PDKProfileOutputError { deliveryError = error }
        catch { deliveryError = .codec(error) }
        return .init(exitCode: deliveryError == nil ? refusalExitCode : 1, output: nil,
            isStandardError: true, failure: error, deliveryFailure: deliveryError, owners: owners)
    }
}
