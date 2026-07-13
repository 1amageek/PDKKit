import Foundation
import CircuiteFoundation
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

    func execute(options: Options) throws -> PDKKitCLIInvocationResult {
        let data: Data
        do {
            data = try Data(contentsOf: URL(filePath: options.manifestPath))
        } catch {
            throw PDKKitCLIError.unreadableFile(path: options.manifestPath, reason: error.localizedDescription)
        }
        let migration: PDKManifestMigrationResult
        do {
            migration = try PDKManifestCodec.decode(data: data)
        } catch {
            throw PDKKitCLIError.invalidJSON(path: options.manifestPath, reason: String(describing: error))
        }
        let digest: String
        do {
            let location = try ArtifactLocation(fileURL: URL(filePath: options.manifestPath).standardizedFileURL)
            let artifact = try LocalArtifactReferencer().reference(
                ArtifactLocator(location: location, kind: .technology, format: .json)
            )
            digest = artifact.digest.hexadecimalValue
        } catch {
            throw PDKKitCLIError.internalError("Failed to hash manifest: \(error)")
        }
        let output = PDKKitInspectOutput(
            command: "inspect",
            manifestPath: URL(filePath: options.manifestPath).standardizedFileURL.path,
            sourceSchemaVersion: migration.sourceSchemaVersion,
            targetSchemaVersion: migration.targetSchemaVersion,
            wasMigrated: migration.wasMigrated,
            digest: digest,
            manifest: migration.manifest
        )
        return PDKKitCLIInvocationResult(
            exitCode: 0,
            standardOutput: try PDKKitCLIJSONCoding.encode(output, pretty: options.pretty) + "\n",
            standardError: ""
        )
    }
}
