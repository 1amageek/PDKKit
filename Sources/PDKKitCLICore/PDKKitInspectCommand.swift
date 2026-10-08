import PDKDiscovery
import PDKSourceCapture
import Foundation
import CircuiteFoundation
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
import PDKCore

struct PDKKitInspectCommand: Sendable {
    struct Options: Sendable, Equatable {
        var manifestPath: String
        var pretty: Bool

        init(arguments: [String]) throws {
            var manifestPath: String?
            var pretty = false
            var cursor = PDKKitCLIArgumentCursor(arguments: arguments)
            while let argument = cursor.next() {
                switch argument {
                case "--manifest": manifestPath = try cursor.requireValue(for: argument)
                case "--pretty": pretty = true
                default: throw PDKKitCLIError.invalidArguments("Unknown argument for inspect: \(argument)")
                }
            }
            guard let manifestPath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --manifest")
            }
            self.manifestPath = manifestPath
            self.pretty = pretty
        }
    }

    func execute(options: Options) async throws -> PDKKitCLIInvocationResult {
        let url = URL(filePath: options.manifestPath).standardizedFileURL
        let loaded = try await LocalPDKManifestLoader().discover(
            at: ArtifactLocator(location: ArtifactLocation(fileURL: url), role: .input, kind: .technology, format: .json),
            relativeTo: nil, captureBudget: PDKSourceCapturePolicy.defaultBudget
        )
        let manifest = loaded.manifest
        let digest = loaded.reference.digest
        let output = PDKKitInspectOutput(
            command: "inspect",
            manifestPath: URL(filePath: options.manifestPath).standardizedFileURL.path,
            schemaVersion: manifest.schemaVersion,
            digest: digest,
            manifest: manifest
        )
        return PDKKitCLIInvocationResult(
            exitCode: 0,
            standardOutput: try PDKKitCLIJSONCoding.encode(output, pretty: options.pretty) + "\n",
            standardError: ""
        )
    }
}
