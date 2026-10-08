import CircuiteFoundation
import PDKCore
import PDKDiscovery
import PDKProfileAdmission

extension NativePDKProfileCommand {
    func root(_ id: ArtifactRootID, availability: PDKProfileCLIAvailability,
              work: PDKProfileCommandWork) throws -> PDKProfileAuthorizedRoot {
        for root in availability.roots {
            if try work.equal(root.rootID.rawValue, id.rawValue) { return root }
        }
        throw PDKProfileCommandError.invalidArguments
    }
    func sameReference(_ a: ArtifactReference, _ b: ArtifactReference, work: PDKProfileCommandWork) throws -> Bool {
        try work.step()
        guard a.byteCount == b.byteCount, a.digest.algorithm == b.digest.algorithm else { return false }
        return try work.equal(a.digest.hexadecimalValue, b.digest.hexadecimalValue)
            && work.equal(a.descriptor.role.rawValue, b.descriptor.role.rawValue)
            && work.equal(a.descriptor.kind.rawValue, b.descriptor.kind.rawValue)
            && work.equal(a.descriptor.format.rawValue, b.descriptor.format.rawValue)
    }
    func plan(availability: PDKProfileCLIAvailability, owners: inout PDKProfileCommandOwners,
              work: PDKProfileCommandWork) async throws {
        guard let binding = availability.definition else { throw PDKProfileCommandError.invalidArguments }
        let authorized = try root(binding.rootID, availability: availability, work: work)
        let source = try await capture.capture(reference: binding.reference, rootURL: authorized.rootURL,
            rootID: binding.rootID, relativePath: binding.relativePath, budget: binding.budget, resources: work.resources)
        owners.definitionCapture = source
        let document = try decoder.decodeDefinition(source, accounting: work.resources)
        owners.definitionDocument = document
        guard let decodedReference = document.sourceReference,
              try sameReference(decodedReference, source.reference, work: work),
              try sameReference(document.value.manifestReference, availability.manifest.reference, work: work),
              try work.equal(document.value.inspectionPolicyIdentity, availability.inspectionPolicyIdentity) else {
            throw PDKProfileCommandError.invalidArguments
        }
        let manifest = try await loadManifest(availability: availability, work: work)
        owners.manifest = manifest
        let plan = try LocalPDKProfilePlanner().plan(.init(definition: document.value, manifest: manifest.manifest,
            manifestReference: manifest.reference, resources: work.resources))
        owners.definition = document.value; owners.plan = plan
    }
    func loadManifest(availability: PDKProfileCLIAvailability, work: PDKProfileCommandWork)
        async throws -> PDKBoundedLoadedManifest {
        let binding = availability.manifest
        let authorized = try root(binding.rootID, availability: availability, work: work)
        return try await manifests.loadExact(reference: binding.reference, rootURL: authorized.rootURL,
            rootID: binding.rootID, relativePath: binding.relativePath, budget: binding.budget, resources: work.resources)
    }
}
