import CircuiteFoundation
import PDKCore

struct PDKProfileAvailability: Sendable {
    let request: PDKProfileAdmissionRequest
    let work: PDKAdmissionWork
    func validate() throws(PDKProfileAdmissionError) {
        for index in request.roots.indices {
            try work.charge(.searchRoots)
            for prior in request.roots[..<index] {
                if try work.equal(prior.rootID.rawValue, request.roots[index].rootID.rawValue) { throw .ambiguousAvailability }
                if try work.equal(prior.binding, request.roots[index].binding) { throw .ambiguousAvailability }
            }
        }
        for index in request.sources.indices {
            try work.step()
            for prior in request.sources[..<index] {
                if try work.equal(prior.sourceKey, request.sources[index].sourceKey) { throw .ambiguousAvailability }
            }
            _ = try root(request.sources[index].rootID)
        }
        _ = try root(request.definition.rootID); _ = try root(request.manifest.rootID)
    }
    func root(_ id: ArtifactRootID) throws(PDKProfileAdmissionError) -> PDKProfileAuthorizedRoot {
        for root in request.roots { if try work.equal(root.rootID.rawValue, id.rawValue) { return root } }
        throw .missingBinding
    }
    func source(_ source: PDKProfileSource) throws(PDKProfileAdmissionError) -> PDKProfileSourceBinding {
        for binding in request.sources {
            guard try work.equal(binding.sourceKey, source.sourceKey) else { continue }
            for route in source.logicalRoutes { if try work.equal(binding.logicalRoute, route) { return binding } }
            throw .missingBinding
        }
        throw .missingBinding
    }
}
