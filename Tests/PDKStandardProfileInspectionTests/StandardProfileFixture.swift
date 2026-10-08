import CircuiteFoundation
import CircuiteFoundationFileSystem
import Foundation
import PDKCore
import PDKDiscovery
import PDKProfileAdmission
import PDKSourceCapture
import TechIR
import Testing

struct StandardProfileFixture {
    let root: URL
    let rootID: ArtifactRootID
    let access: ArtifactAccessBudget
    let budget: PDKAdmissionBudget
    let request: PDKProfileAdmissionRequest
    let reference: ArtifactReference

    static var library: IRTechLibrary {
        IRTechLibrary(name: "actual", layers: [.init(name: "M1", type: .routing, gdsLayer: -7,
            gdsDatatype: 2, pitch: .xy(x: 1, y: 2))],
            vias: [.init(name: "V1", cutLayerName: "cut", topLayerName: "M2", bottomLayerName: "M1")],
            sites: [.init(name: "S1", width: 1, height: 2)])
    }
    static func make(bytes: Data? = nil, library: IRTechLibrary = Self.library, format: ArtifactFormat = .json,
                     demands: [String] = ["layers", "vias", "sites", "dependencyClosure"],
                     view: PDKViewKind = .layerMap, section: String? = nil,
                     fullLayer: Bool = false, corner: Bool = false,
                     physicalNames: [String] = ["M1", "V1", "S1"]) async throws -> Self {
        let root = FileManager.default.temporaryDirectory.appending(path: "pdk-standard-profile-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let rootID = try ArtifactRootID(rawValue: UUID().uuidString)
        let access = try ArtifactAccessBudget(maximumPageByteCount: 4096, maximumTotalByteCount: 10_000_000,
            maximumPageCount: 10_000, maximumWorkUnitCount: 100_000_000, maximumDurationNanoseconds: 10_000_000_000)
        let budget = try Self.budget()
        func write(_ data: Data, path: String, kind: String, format: ArtifactFormat) async throws -> ArtifactReference {
            try data.write(to: root.appending(path: path))
            let resources = LocalPDKAdmissionResources(budget: budget); defer { resources.close() }
            return try await LocalPDKBoundedSourceCapturer().discover(descriptor: .init(role: .input,
                kind: ArtifactKind(rawValue: kind), format: format), rootURL: root, rootID: rootID,
                relativePath: ArtifactRelativePath(segments: [path]), budget: access, resources: resources).reference
        }
        let data = try bytes ?? JSONEncoder().encode(library)
        let source = try await write(data, path: "technology.json", kind: "pdk.technology", format: format)
        let corners = corner ? ["tt"] : []
        let pvt = PDKPVTCondition(process: .init(name: "typical", nominal: true), voltage: 1, temperatureCelsius: 25)
        let manifest = try PDKManifest(processID: "p", version: "1", assets: [
            .init(assetID: "tech", role: .technology, path: "technology.json", kind: ArtifactKind(rawValue: "technology"),
                format: format, required: true, sha256: source.digest.hexadecimalValue,
                byteCount: Int64(source.byteCount), cornerIDs: corners)],
            layers: fullLayer ? [.init(layerID: "m1", name: "M1", number: 1, purpose: .drawing)] : [],
            corners: corner ? [.init(cornerID: "tt", pvt: pvt, assetIDs: ["tech"], viewMappings: [view.rawValue: "tech"])] : [],
            crossViewMappings: [.init(mappingID: "actual", view: view, assetID: "tech", physicalNames: physicalNames,
                layerIDs: fullLayer ? ["m1"] : [], cornerIDs: corners)])
        let manifestRef = try await write(PDKManifestCodec.encode(manifest), path: "pdk.json", kind: "pdk.technology", format: .json)
        let requirement = try PDKViewRequirement(requirementID: "technology", purposeID: "mapping", view: view,
            role: .technology, assetIDs: ["tech"], cornerIDs: corners, selectedSection: section, isShared: !corner,
            allowsMultipleSources: false, demandedFactKinds: demands)
        let definition = try PDKProfileDefinition(profileID: "actual", manifestReference: manifestRef, processID: "p", version: "1",
            requiredCornerIDs: corners, requirements: [requirement], sources: [
                .init(sourceKey: "tech", assetID: "tech", reference: source, logicalRoutes: ["technology.json"])],
            orderedSearchRoutes: ["models"], dependencies: [], inspectionPolicyIdentity: "policy.v1",
            initialPreprocessingIdentity: "shared.mixed-format.provenance")
        let definitionRef = try await write(PDKProfileCodec().encodeDefinition(definition), path: "profile.json", kind: "pdk.profile", format: .json)
        let request = try PDKProfileAdmissionRequest(definition: .init(reference: definitionRef, rootID: rootID,
            relativePath: ArtifactRelativePath(segments: ["profile.json"]), budget: access),
            manifest: .init(reference: manifestRef, rootID: rootID, relativePath: ArtifactRelativePath(segments: ["pdk.json"]), budget: access),
            roots: [PDKProfileAuthorizedRoot(rootID: rootID, rootURL: root)],
            sources: [.init(sourceKey: "tech", logicalRoute: "technology.json", rootID: rootID,
                relativePath: ArtifactRelativePath(segments: ["technology.json"]), budget: access)],
            budget: budget, inspectionPolicyIdentity: "policy.v1")
        return .init(root: root, rootID: rootID, access: access, budget: budget, request: request, reference: source)
    }
    static func budget(limits: [PDKAdmissionResourceDimension: UInt64] = [:], elapsed: UInt64 = 10_000_000_000) throws -> PDKAdmissionBudget {
        var values: [PDKAdmissionResourceDimension: UInt64] = [:]
        for dimension in PDKAdmissionResourceDimension.allCases { values[dimension] = limits[dimension] ?? 100_000_000 }
        return try .init(limits: values, maximumElapsedNanoseconds: elapsed)
    }
    func capture(resources: any PDKAdmissionResourceAccounting, descriptor: ArtifactDescriptor? = nil) async throws -> CapturedPDKSource {
        if let descriptor {
            return try await LocalPDKBoundedSourceCapturer().discover(descriptor: descriptor, rootURL: root, rootID: rootID,
                relativePath: ArtifactRelativePath(segments: ["technology.json"]), budget: access, resources: resources)
        }
        return try await LocalPDKBoundedSourceCapturer().capture(reference: reference, rootURL: root, rootID: rootID,
            relativePath: ArtifactRelativePath(segments: ["technology.json"]), budget: access, resources: resources)
    }
    func remove() {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record("Fixture cleanup failed: \(error)") }
    }
}
