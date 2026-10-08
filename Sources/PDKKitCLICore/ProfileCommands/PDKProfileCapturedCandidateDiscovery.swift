import Foundation
import CircuiteFoundation
import PDKCore
import PDKSourceCapture
import PDKDiscovery
import PDKProfileAdmission

/// Only the private proposal invocation can lend this immutable, already captured pool.
struct PDKProfileCapturedCandidateDiscovery: PDKLocalSourceDiscovering {
    let authoring: PDKDecodedDocument<PDKProfileCLIAuthoring>
    let availability: PDKDecodedDocument<PDKProfileCLIAvailability>
    let captures: [CapturedPDKSource]

    func discover(descriptor: ArtifactDescriptor, rootURL: URL, rootID: ArtifactRootID,
                  relativePath: ArtifactRelativePath, budget: ArtifactAccessBudget,
                  resources: any PDKAdmissionResourceAccounting) async throws(PDKSourceCaptureError) -> CapturedPDKSource {
        let work = PDKProfileCommandWork(resources: resources)
        do {
            for index in authoring.value.candidateSources.indices {
                try work.step()
                let candidate = authoring.value.candidateSources[index]
                guard let binding = candidate.bindings.first, binding.rootID == rootID,
                      binding.budget == budget else { continue }
                guard try samePath(binding.relativePath, relativePath, work: work) else { continue }
                for root in availability.value.roots {
                    if try work.equal(root.rootID.rawValue, rootID.rawValue) {
                        _ = try work.bytes(root.rootURL.absoluteString); _ = try work.bytes(rootURL.absoluteString)
                        guard root.rootURL == rootURL else { throw PDKAdmissionResourceError.unsupportedBudgetCapability("Candidate root changed") }
                    }
                }
                guard try work.equal(candidate.descriptor.role.rawValue, descriptor.role.rawValue),
                      try work.equal(candidate.descriptor.kind.rawValue, descriptor.kind.rawValue),
                      try work.equal(candidate.descriptor.format.rawValue, descriptor.format.rawValue) else { continue }
                try resources.check(); return captures[index]
            }
            throw PDKAdmissionResourceError.unsupportedBudgetCapability("Candidate capture pool has no exact authorized binding")
        } catch let error as PDKAdmissionResourceError { throw .resource(error) }
        catch let error as PDKSourceCaptureError { throw error }
        catch { throw .resource(.unsupportedBudgetCapability("Candidate capture pool validation failed")) }
    }
    private func samePath(_ a: ArtifactRelativePath, _ b: ArtifactRelativePath, work: PDKProfileCommandWork) throws -> Bool {
        try work.step()
        guard a.segments.count == b.segments.count else { return false }
        for index in a.segments.indices { if try !work.equal(a.segments[index], b.segments[index]) { return false } }
        return true
    }
}
