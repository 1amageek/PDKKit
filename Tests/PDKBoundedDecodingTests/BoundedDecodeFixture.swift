import Foundation
import CircuiteFoundation
import CircuiteFoundationFoundation
import PDKCore

struct BoundedDecodeFixture {
    static func reference(_ digit: String, kind: String, format: ArtifactFormat) throws -> ArtifactReference {
        try ArtifactReference(digest: ContentDigest(algorithm: .sha256, hexadecimalValue: String(repeating: digit, count: 64)),
            byteCount: 4, descriptor: ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: kind), format: format))
    }
    static func values() throws -> (PDKManifest, PDKProfileDefinition, PDKProfileClaim) {
        let manifestReference = try reference("a", kind: "pdk.technology", format: .json)
        let modelReference = try reference("1", kind: "pdk.spice", format: .spice)
        let source = try PDKProfileSource(sourceKey: "root", assetID: "model", reference: modelReference, logicalRoutes: ["model.sp"])
        let requirement = try PDKViewRequirement(requirementID: "simulation", purposeID: "transient", view: .spice,
            role: .model, assetIDs: ["model"], cornerIDs: ["tt"], selectedSection: nil, isShared: false,
            allowsMultipleSources: false, demandedFactKinds: ["devices", "dependencies"])
        let definition = try PDKProfileDefinition(profileID: "demo", manifestReference: manifestReference, processID: "p", version: "1",
            requiredCornerIDs: ["tt"], requirements: [requirement], sources: [source], orderedSearchRoutes: ["models"], dependencies: [],
            inspectionPolicyIdentity: "policy.v1", initialPreprocessingIdentity: "environment.empty.v1")
        let pvt = PDKPVTCondition(process: PDKProcessCorner(name: "typical", nominal: true), voltage: 1, temperatureCelsius: 25)
        let asset = try PDKAssetReference(assetID: "model", role: .model, path: "model.sp", kind: ArtifactKind(rawValue: "spice"),
            format: .spice, sha256: String(repeating: "1", count: 64), byteCount: 4, cornerIDs: ["tt"])
        let manifest = PDKManifest(processID: "p", version: "1", assets: [asset],
            corners: [PDKCornerDefinition(cornerID: "tt", pvt: pvt, assetIDs: ["model"], viewMappings: ["spice": "model"])],
            crossViewMappings: [PDKCrossViewMapping(mappingID: "spice", view: .spice, assetID: "model", cornerIDs: ["tt"])])
        let claim = try PDKProfileClaim(definitionReference: reference("d", kind: "pdk.profile", format: .json),
            plan: PDKProfilePlan(definition: definition, manifest: manifest, manifestReference: manifestReference))
        return (manifest, definition, claim)
    }
}
