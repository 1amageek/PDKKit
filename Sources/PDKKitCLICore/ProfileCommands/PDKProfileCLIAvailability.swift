import CircuiteFoundation
import PDKCore
import PDKProfileAdmission

public struct PDKProfileCLIAvailability: Sendable, Codable {
    public static let artifactDescriptor: ArtifactDescriptor = {
        do { return .init(role: .input, kind: try ArtifactKind(rawValue: "pdk.profile-availability"), format: .json) }
        catch { preconditionFailure("The fixed availability artifact kind must be valid") }
    }()
    public let roots: [PDKProfileAuthorizedRoot]
    public let definition: PDKProfileExactBinding?
    public let manifest: PDKProfileExactBinding
    public let sources: [PDKProfileSourceBinding]
    public let claim: PDKProfileExactBinding?
    public let inspectionPolicyIdentity: String

    public init(roots: [PDKProfileAuthorizedRoot], definition: PDKProfileExactBinding?,
                manifest: PDKProfileExactBinding, sources: [PDKProfileSourceBinding],
                claim: PDKProfileExactBinding?, inspectionPolicyIdentity: String,
                resources: any PDKAdmissionResourceAccounting) throws {
        try PDKCLIInputCoding.id(inspectionPolicyIdentity, resources: resources)
        guard !roots.isEmpty else { throw PDKProfileCLIInputError.invalidBinding }
        for index in roots.indices {
            try PDKCLIInputCoding.work(resources)
            for prior in roots[..<index] {
                if try PDKCLIInputCoding.equal(prior.rootID.rawValue, roots[index].rootID.rawValue, resources: resources)
                    || prior.rootURL == roots[index].rootURL { throw PDKProfileCLIInputError.invalidBinding }
            }
        }
        func rootExists(_ id: ArtifactRootID) throws -> Bool {
            for root in roots { if try PDKCLIInputCoding.equal(root.rootID.rawValue, id.rawValue, resources: resources) { return true } }
            return false
        }
        guard try rootExists(manifest.rootID) else { throw PDKProfileCLIInputError.invalidBinding }
        if let definition, !(try rootExists(definition.rootID)) { throw PDKProfileCLIInputError.invalidBinding }
        if let claim, !(try rootExists(claim.rootID)) { throw PDKProfileCLIInputError.invalidBinding }
        for index in sources.indices {
            let source = sources[index]
            try PDKCLIInputCoding.id(source.sourceKey, resources: resources)
            try PDKCLIInputCoding.route(source.logicalRoute, resources: resources)
            guard try rootExists(source.rootID) else { throw PDKProfileCLIInputError.invalidBinding }
            for prior in sources[..<index] {
                let sameKey = try PDKCLIInputCoding.equal(prior.sourceKey, source.sourceKey, resources: resources)
                let sameRoute = try PDKCLIInputCoding.equal(prior.logicalRoute, source.logicalRoute, resources: resources)
                if sameRoute { throw PDKProfileCLIInputError.invalidBinding }
                if sameKey && (prior.rootID != source.rootID || prior.relativePath != source.relativePath || prior.budget != source.budget) {
                    throw PDKProfileCLIInputError.invalidBinding
                }
            }
        }
        self.roots = roots; self.definition = definition; self.manifest = manifest
        self.sources = sources; self.claim = claim; self.inspectionPolicyIdentity = inspectionPolicyIdentity
        try resources.check()
    }
    enum CodingKeys: String, CodingKey, CaseIterable { case schemaVersion, roots, definition, manifest, sources, claim, inspectionPolicyIdentity }
    public init(from decoder: any Decoder) throws {
        let resources = try PDKCLIInputCoding.resources(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try PDKCLIInputCoding.check(c, fields: CodingKeys.allCases)
        let roots = try c.decode([PDKCLIRootWire].self, forKey: .roots)
        let sources = try c.decode([PDKCLISourceBindingWire].self, forKey: .sources)
        try PDKCLIInputCoding.capacity(PDKProfileAuthorizedRoot.self, count: roots.count, resources: resources)
        try PDKCLIInputCoding.capacity(PDKProfileSourceBinding.self, count: sources.count, resources: resources)
        var checkedRoots: [PDKProfileAuthorizedRoot] = []; checkedRoots.reserveCapacity(roots.count)
        var checkedSources: [PDKProfileSourceBinding] = []; checkedSources.reserveCapacity(sources.count)
        for root in roots { try PDKCLIInputCoding.work(resources); checkedRoots.append(root.value) }
        for source in sources { try PDKCLIInputCoding.work(resources); checkedSources.append(source.value) }
        try self.init(roots: checkedRoots, definition: c.decodeIfPresent(PDKCLIExactBindingWire.self, forKey: .definition)?.value,
            manifest: c.decode(PDKCLIExactBindingWire.self, forKey: .manifest).value, sources: checkedSources,
            claim: c.decodeIfPresent(PDKCLIExactBindingWire.self, forKey: .claim)?.value,
            inspectionPolicyIdentity: c.decode(String.self, forKey: .inspectionPolicyIdentity), resources: resources)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion)
        var roots = c.nestedUnkeyedContainer(forKey: .roots)
        for root in self.roots { try roots.encode(PDKCLIRootWire(root)) }
        if let definition { try c.encode(PDKCLIExactBindingWire(definition), forKey: .definition) } else { try c.encodeNil(forKey: .definition) }
        try c.encode(PDKCLIExactBindingWire(manifest), forKey: .manifest)
        var sources = c.nestedUnkeyedContainer(forKey: .sources)
        for source in self.sources { try sources.encode(PDKCLISourceBindingWire(source)) }
        if let claim { try c.encode(PDKCLIExactBindingWire(claim), forKey: .claim) } else { try c.encodeNil(forKey: .claim) }
        try c.encode(inspectionPolicyIdentity, forKey: .inspectionPolicyIdentity)
    }
}
