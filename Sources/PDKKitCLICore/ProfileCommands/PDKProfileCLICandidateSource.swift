import CircuiteFoundation
import CircuiteFoundationFoundation
import PDKCore
import PDKProfileAdmission

public struct PDKProfileCLICandidateSource: Sendable, Codable {
    public let sourceKey: String
    public let assetID: String?
    public let descriptor: ArtifactDescriptor
    public let logicalRoutes: [String]
    public let bindings: [PDKProfileSourceBinding]
    public init(sourceKey: String, assetID: String?, descriptor: ArtifactDescriptor,
                logicalRoutes: [String], bindings: [PDKProfileSourceBinding],
                resources: any PDKAdmissionResourceAccounting) throws {
        try PDKCLIInputCoding.id(sourceKey, resources: resources)
        if let assetID { try PDKCLIInputCoding.id(assetID, resources: resources) }
        try PDKCLIInputCoding.unique(logicalRoutes, resources: resources)
        guard !logicalRoutes.isEmpty, bindings.count == logicalRoutes.count, let first = bindings.first else {
            throw PDKProfileCLIInputError.invalidBinding
        }
        for route in logicalRoutes {
            try PDKCLIInputCoding.route(route, resources: resources)
            var matches = 0
            for binding in bindings {
                try PDKCLIInputCoding.work(resources)
                if try PDKCLIInputCoding.equal(binding.logicalRoute, route, resources: resources) { matches += 1 }
                guard try PDKCLIInputCoding.equal(binding.sourceKey, sourceKey, resources: resources),
                      binding.rootID == first.rootID, binding.relativePath == first.relativePath,
                      binding.budget == first.budget else { throw PDKProfileCLIInputError.invalidBinding }
            }
            guard matches == 1 else { throw PDKProfileCLIInputError.invalidBinding }
        }
        self.sourceKey = sourceKey; self.assetID = assetID; self.descriptor = descriptor
        self.logicalRoutes = logicalRoutes; self.bindings = bindings
        try resources.check()
    }
    enum CodingKeys: String, CodingKey, CaseIterable { case schemaVersion, sourceKey, assetID, descriptor, logicalRoutes, bindings }
    public init(from decoder: any Decoder) throws {
        let resources = try PDKCLIInputCoding.resources(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try PDKCLIInputCoding.check(c, fields: CodingKeys.allCases)
        let bindings = try c.decode([PDKCLISourceBindingWire].self, forKey: .bindings)
        try PDKCLIInputCoding.capacity(PDKProfileSourceBinding.self, count: bindings.count, resources: resources)
        var checked: [PDKProfileSourceBinding] = []; checked.reserveCapacity(bindings.count)
        for binding in bindings { try PDKCLIInputCoding.work(resources); checked.append(binding.value) }
        try self.init(sourceKey: c.decode(String.self, forKey: .sourceKey), assetID: c.decodeIfPresent(String.self, forKey: .assetID),
            descriptor: c.decode(ArtifactDescriptor.self, forKey: .descriptor),
            logicalRoutes: c.decode([String].self, forKey: .logicalRoutes), bindings: checked, resources: resources)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion); try c.encode(sourceKey, forKey: .sourceKey)
        try c.encode(assetID, forKey: .assetID); try c.encode(descriptor, forKey: .descriptor)
        try c.encode(logicalRoutes, forKey: .logicalRoutes)
        var bindings = c.nestedUnkeyedContainer(forKey: .bindings)
        for binding in self.bindings { try bindings.encode(PDKCLISourceBindingWire(binding)) }
    }
}
