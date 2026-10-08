import CircuiteFoundation
import Foundation
import PDKProfileAdmission

struct PDKCLIRootWire: Codable, Sendable {
    let value: PDKProfileAuthorizedRoot
    init(_ value: PDKProfileAuthorizedRoot) { self.value = value }
    enum CodingKeys: String, CodingKey, CaseIterable { case schemaVersion, rootID, directoryPath }
    init(from decoder: any Decoder) throws {
        let resources = try PDKCLIInputCoding.resources(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try PDKCLIInputCoding.check(c, fields: CodingKeys.allCases)
        let name = try c.decode(String.self, forKey: .rootID)
        let path = try c.decode(String.self, forKey: .directoryPath)
        try PDKCLIInputCoding.id(name, resources: resources)
        try PDKCLIInputCoding.work(resources, UInt64(path.utf8.count) + 1)
        guard path.hasPrefix("/"), !path.utf8.contains(0) else { throw PDKProfileCLIInputError.invalidBinding }
        let (pathBytes, overflow) = path.utf8.count.multipliedReportingOverflow(by: 6)
        let (bytes, prefixOverflow) = pathBytes.addingReportingOverflow(32)
        guard !overflow, !prefixOverflow else { throw PDKProfileCLIInputError.invalidBinding }
        try PDKCLIInputCoding.capacity(UInt8.self, count: bytes, resources: resources)
        value = try PDKProfileAuthorizedRoot(rootID: ArtifactRootID(rawValue: name), rootURL: URL(fileURLWithPath: path))
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion)
        try c.encode(value.rootID.rawValue, forKey: .rootID)
        try c.encode(value.rootURL.path, forKey: .directoryPath)
    }
}
