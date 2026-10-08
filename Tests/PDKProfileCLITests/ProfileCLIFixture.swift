import CircuiteFoundation
import Darwin
import Foundation
import PDKCore
import PDKKitCLICore
import PDKProfileAdmission
import PDKSourceCapture
import TechIR
import Testing

struct ProfileCLIFixture {
    let root: PDKProfileAuthorizedRoot
    let access: ArtifactAccessBudget
    let budget: PDKAdmissionBudget
    let manifest: PDKManifest
    let manifestBinding: PDKProfileExactBinding
    let bindings: [PDKProfileSourceBinding]
    let sourceReferences: [String: ArtifactReference]
    let authoringBinding: PDKProfileExactBinding
    var definitionBinding: PDKProfileExactBinding?
    var claimBinding: PDKProfileExactBinding?
    var availabilityBinding: PDKProfileExactBinding
    static let policy = "spice.policy.v1"

    static func make(jsonOnly: Bool = false) async throws -> Self {
        let url = FileManager.default.temporaryDirectory.appending(path: "pdk-profile-cli-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        do {
            let root = try PDKProfileAuthorizedRoot(rootID: ArtifactRootID(rawValue: UUID().uuidString), rootURL: url)
            let access = try ArtifactAccessBudget(maximumPageByteCount: 4096, maximumTotalByteCount: 10_000_000,
                maximumPageCount: 10_000, maximumWorkUnitCount: 100_000_000, maximumDurationNanoseconds: 30_000_000_000)
            let budget = try Self.makeBudget()
            func write(_ bytes: Data, _ name: String, _ descriptor: ArtifactDescriptor) async throws -> PDKProfileExactBinding {
                try bytes.write(to: url.appending(path: name))
                let resources = LocalPDKAdmissionResources(budget: budget)
                defer { resources.close() }
                let path = try ArtifactRelativePath(segments: [name])
                let capture = try await LocalPDKBoundedSourceCapturer().discover(descriptor: descriptor,
                    rootURL: url, rootID: root.rootID, relativePath: path, budget: access, resources: resources)
                return .init(reference: capture.reference, rootID: root.rootID, relativePath: path, budget: access)
            }
            try JSONEncoder().encode(budget).write(to: url.appending(path: "budget.json"))
            let spice = try ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: "pdk.spice"), format: .spice)
            let technology = try ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: "pdk.technology"), format: .json)
            let library = IRTechLibrary(name: "actual", layers: [.init(name: "M1", type: .routing, gdsLayer: 1)],
                vias: [.init(name: "V1", cutLayerName: "cut", topLayerName: "M2", bottomLayerName: "M1")],
                sites: [.init(name: "S1", width: 1, height: 2)])
            let tech = try await write(JSONEncoder().encode(library), "technology.json", technology)
            var assets: [PDKAssetReference] = []
            var mappings: [PDKCrossViewMapping] = []
            var routes: [(String, String)] = []
            var references: [String: ArtifactReference] = ["tech": tech.reference]
            if !jsonOnly {
                let rootSource = try await write(Data("* root\n.include \"child.sp\"\n.model m NMOS (level=1 vto=0.4)\n".utf8), "root.sp", spice)
                let child = try await write(Data("* actual dependency\n.model child PMOS (level=1 vto=-0.4)\n".utf8), "child.sp", spice)
                references["root"] = rootSource.reference; references["child"] = child.reference
                assets.append(.init(assetID: "model", role: .model, path: "root.sp", kind: try ArtifactKind(rawValue: "spice"),
                    format: .spice, required: true, sha256: rootSource.reference.digest.hexadecimalValue,
                    byteCount: Int64(rootSource.reference.byteCount)))
                mappings.append(.init(mappingID: "models", view: .spice, assetID: "model", logicalNames: ["m"]))
                routes += [("root", "root.sp"), ("child", "child.sp")]
            }
            assets.append(try
                .init(assetID: "tech", role: .technology, path: "technology.json", kind: ArtifactKind(rawValue: "technology"),
                    format: .json, required: true, sha256: tech.reference.digest.hexadecimalValue,
                    byteCount: Int64(tech.reference.byteCount)))
            mappings.append(.init(mappingID: "physical", view: .layerMap, assetID: "tech", physicalNames: ["M1", "V1", "S1"]))
            routes.append(("tech", "technology.json"))
            let manifest = PDKManifest(processID: "cli-process", version: "1", assets: assets, crossViewMappings: mappings)
            let manifestBinding = try await write(PDKManifestCodec.encode(manifest), "pdk.json", technology)
            let bindings = try routes.map {
                PDKProfileSourceBinding(sourceKey: $0.0, logicalRoute: $0.1, rootID: root.rootID,
                    relativePath: try ArtifactRelativePath(segments: [$0.1]), budget: access)
            }
            let resources = LocalPDKAdmissionResources(budget: budget)
            defer { resources.close() }
            let candidates = try bindings.map { binding in
                try PDKProfileCLICandidateSource(sourceKey: binding.sourceKey,
                    assetID: binding.sourceKey == "root" ? "model" : binding.sourceKey == "tech" ? "tech" : nil,
                    descriptor: binding.sourceKey == "tech" ? technology : spice, logicalRoutes: [binding.logicalRoute],
                    bindings: [binding], resources: resources)
            }
            var requirements: [PDKViewRequirement] = []
            if !jsonOnly {
                requirements.append(try PDKViewRequirement(requirementID: "simulation", purposeID: "transient", view: .spice,
                    role: .model, assetIDs: ["model"], cornerIDs: [], selectedSection: nil, isShared: true,
                    allowsMultipleSources: false, demandedFactKinds: ["devices", "dependencyClosure"]))
            }
            requirements.append(try PDKViewRequirement(requirementID: "technology", purposeID: "mapping", view: .layerMap,
                    role: .technology, assetIDs: ["tech"], cornerIDs: [], selectedSection: nil, isShared: true,
                    allowsMultipleSources: false, demandedFactKinds: ["layers", "vias", "sites", "dependencyClosure"]))
            let authoring = try PDKProfileCLIAuthoring(profileID: "cli-profile", requiredCornerIDs: [],
                requirements: requirements, orderedSearchRoutes: [], inspectionPolicyIdentity: policy,
                candidateSources: candidates, resources: resources)
            let authoringBinding = try await write(JSONEncoder().encode(authoring), "authoring.json", PDKProfileCLIAuthoring.artifactDescriptor)
            let availability = try PDKProfileCLIAvailability(roots: [root], definition: nil, manifest: manifestBinding,
                sources: bindings, claim: nil, inspectionPolicyIdentity: policy, resources: resources)
            let availabilityBinding = try await write(JSONEncoder().encode(availability), "availability.json", PDKProfileCLIAvailability.artifactDescriptor)
            return .init(root: root, access: access, budget: budget, manifest: manifest, manifestBinding: manifestBinding,
                bindings: bindings, sourceReferences: references,
                authoringBinding: authoringBinding, definitionBinding: nil, claimBinding: nil, availabilityBinding: availabilityBinding)
        } catch {
            do { try FileManager.default.removeItem(at: url) }
            catch { Issue.record("Partial fixture cleanup failed: \(error)") }
            throw error
        }
    }

    static func makeBudget(overrides: [PDKAdmissionResourceDimension: UInt64] = [:]) throws -> PDKAdmissionBudget {
        try .init(limits: Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map {
            ($0, overrides[$0] ?? 100_000_000)
        }), maximumElapsedNanoseconds: 30_000_000_000)
    }

    func arguments(_ verb: String) -> [String] {
        var result = ["profile", verb, "--input-root", root.rootURL.path, "--input-root-id", root.rootID.rawValue,
            "--budget", "budget.json", "--availability", "availability.json", "--availability-sha256",
            availabilityBinding.reference.digest.hexadecimalValue, "--availability-bytes", String(availabilityBinding.reference.byteCount)]
        if verb == "propose" {
            result += ["--authoring", "authoring.json", "--authoring-sha256", authoringBinding.reference.digest.hexadecimalValue,
                "--authoring-bytes", String(authoringBinding.reference.byteCount)]
        }
        return result
    }

    func write(_ bytes: Data, name: String, descriptor: ArtifactDescriptor) async throws -> PDKProfileExactBinding {
        try bytes.write(to: root.rootURL.appending(path: name))
        let resources = LocalPDKAdmissionResources(budget: budget)
        defer { resources.close() }
        let path = try ArtifactRelativePath(segments: [name])
        let capture = try await LocalPDKBoundedSourceCapturer().discover(descriptor: descriptor,
            rootURL: root.rootURL, rootID: root.rootID, relativePath: path, budget: access, resources: resources)
        return .init(reference: capture.reference, rootID: root.rootID, relativePath: path, budget: access)
    }

    mutating func adopt(_ definition: PDKProfileDefinition) async throws {
        definitionBinding = try await write(PDKProfileCodec().encodeDefinition(definition), name: "profile.json",
            descriptor: ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: "pdk.profile"), format: .json))
        try await refreshAvailability()
    }

    mutating func retain(_ claim: PDKProfileClaim) async throws {
        claimBinding = try await write(PDKProfileCodec().encodeClaim(claim), name: "claim.json",
            descriptor: ArtifactDescriptor(role: .input, kind: ArtifactKind(rawValue: "pdk.profile-claim"), format: .json))
        try await refreshAvailability()
    }

    mutating func refreshAvailability(sources: [PDKProfileSourceBinding]? = nil) async throws {
        let resources = LocalPDKAdmissionResources(budget: budget)
        defer { resources.close() }
        let availability = try PDKProfileCLIAvailability(roots: [root], definition: definitionBinding, manifest: manifestBinding,
            sources: sources ?? bindings, claim: claimBinding, inspectionPolicyIdentity: Self.policy, resources: resources)
        availabilityBinding = try await write(JSONEncoder().encode(availability), name: "availability.json",
            descriptor: PDKProfileCLIAvailability.artifactDescriptor)
    }

    static func data(_ output: PDKOwnedProfileOutput) -> Data {
        output.withBytes { bytes in
            var copy = Data(); copy.reserveCapacity(bytes.count)
            for index in 0..<bytes.count { copy.append(bytes[index]) }
            return copy
        }
    }

    static func envelope(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func field<T: Decodable>(_ type: T.Type, name: String, in envelope: [String: Any]) throws -> T {
        let value = try #require(envelope[name])
        return try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
    }

    func invoke(_ verb: String) async throws -> [String: Any] {
        let result = await PDKKitCLI.invoke(arguments: arguments(verb))
        #expect(result.exitCode == 0)
        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.isEmpty)
        let profile = try #require(result.profileResult)
        #expect(profile.failure == nil)
        #expect(!profile.isStandardError)
        let output = try #require(profile.output)
        return try Self.envelope(Self.data(output))
    }

    static func executable() throws -> URL {
        if let path = ProcessInfo.processInfo.environment["LSI_PDK_PROFILE_CLI_EXECUTABLE"] {
            #expect(FileManager.default.isExecutableFile(atPath: path))
            return URL(fileURLWithPath: path)
        }
        let testBinary = URL(fileURLWithPath: CommandLine.arguments[0])
        let candidates = [testBinary.deletingLastPathComponent().appending(path: "pdkkit-cli"),
            testBinary.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appending(path: "pdkkit-cli")]
        return try #require(candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) },
            "Build pdkkit-cli beside the test product or set LSI_PDK_PROFILE_CLI_EXECUTABLE")
    }

    struct ProcessReceipt {
        let exitCode: Int32
        let standardOutput: Data
        let standardError: Data
    }

    func execute(_ verb: String, executable: URL) async throws -> ProcessReceipt {
        let token = UUID().uuidString
        let stdoutURL = root.rootURL.appending(path: token + ".stdout")
        let stderrURL = root.rootURL.appending(path: token + ".stderr")
        try Data().write(to: stdoutURL); try Data().write(to: stderrURL)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            do { try stdout.close(); try stderr.close() }
            catch { Issue.record("Process output cleanup failed: \(error)") }
        }
        let process = Process()
        process.executableURL = executable; process.arguments = arguments(verb)
        process.standardOutput = stdout; process.standardError = stderr
        try process.run()
        defer {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
        }
        let clock = ContinuousClock(); let deadline = clock.now.advanced(by: .seconds(20))
        while process.isRunning {
            if clock.now >= deadline || Task.isCancelled {
                process.terminate()
                throw CocoaError(.userCancelled)
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        process.waitUntilExit()
        return try .init(exitCode: process.terminationStatus,
            standardOutput: Data(contentsOf: stdoutURL), standardError: Data(contentsOf: stderrURL))
    }

    func cleanup() {
        do { try FileManager.default.removeItem(at: root.rootURL) }
        catch { Issue.record("Profile CLI fixture cleanup failed: \(error)") }
    }
}
