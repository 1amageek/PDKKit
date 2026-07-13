import Foundation
import CircuiteFoundation
import PDKCore
import PDKStandardViews

struct PDKKitOracleCommand: Sendable {
    struct Options: Sendable, Equatable {
        var manifestPath: String
        var oraclePath: String
        var runID: String
        var pretty: Bool

        init(arguments: [String]) throws {
            var manifestPath: String?
            var oraclePath: String?
            var runID = "pdk-oracle-comparison"
            var pretty = false
            var cursor = PDKKitCLIArgumentCursor(arguments: arguments)
            while let argument = cursor.next() {
                switch argument {
                case "--manifest": manifestPath = try cursor.requireValue(for: argument)
                case "--oracle": oraclePath = try cursor.requireValue(for: argument)
                case "--run-id": runID = try cursor.requireValue(for: argument)
                case "--pretty": pretty = true
                default: throw PDKKitCLIError.invalidArguments("Unknown argument for oracle: \(argument)")
                }
            }
            guard let manifestPath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --manifest")
            }
            guard let oraclePath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --oracle")
            }
            self.manifestPath = manifestPath
            self.oraclePath = oraclePath
            self.runID = runID
            self.pretty = pretty
        }
    }

    func execute(options: Options) async throws -> PDKKitCLIInvocationResult {
        let manifestURL = URL(filePath: options.manifestPath).standardizedFileURL
        let oracleURL = URL(filePath: options.oraclePath).standardizedFileURL
        let pdk: PDKReference
        do {
            pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        } catch {
            throw PDKKitCLIError.invalidJSON(path: manifestURL.path, reason: String(describing: error))
        }
        let oracleReference = try makeOracleReference(for: oracleURL)
        let request = PDKOracleRequest(
            runID: options.runID,
            pdk: pdk,
            oracle: oracleReference
        )
        let envelope = try await LocalPDKOracleComparator().execute(request)
        let output = PDKKitOracleOutput(
            command: "oracle",
            manifestPath: manifestURL.path,
            oraclePath: oracleURL.path,
            runID: options.runID,
            status: envelope.status,
            diagnostics: envelope.diagnostics,
            payload: envelope.payload
        )
        let exitCode: Int32 = envelope.status == .completed ? 0 : 2
        return PDKKitCLIInvocationResult(
            exitCode: exitCode,
            standardOutput: try PDKKitCLIJSONCoding.encode(output, pretty: options.pretty) + "\n",
            standardError: ""
        )
    }

    private func makeOracleReference(for url: URL) throws -> ArtifactReference {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDKKitCLIError.unreadableFile(path: url.path, reason: "file does not exist")
        }
        do {
            let location = try ArtifactLocation(fileURL: url)
            let artifact = try LocalArtifactReferencer().reference(
                ArtifactLocator(
                    location: location,
                    role: .input,
                    kind: .technology,
                    format: .json
                )
            )
            guard artifact.byteCount <= UInt64(Int64.max) else {
                throw PDKKitCLIError.unreadableFile(
                    path: url.path,
                    reason: "file byte count cannot be represented by the artifact contract"
                )
            }
            return artifact
        } catch {
            throw PDKKitCLIError.unreadableFile(path: url.path, reason: error.localizedDescription)
        }
    }
}
