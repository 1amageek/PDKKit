import Foundation
import PDKCore
import PDKStandardViews

struct PDKKitInspectViewCommand: Sendable {
    struct Options: Sendable, Equatable {
        var manifestPath: String
        var assetID: String
        var format: PDKStandardViewFormat
        var runID: String
        var pretty: Bool

        init(arguments: [String]) throws {
            var manifestPath: String?
            var assetID: String?
            var format: PDKStandardViewFormat?
            var runID = "pdk-standard-view-inspection"
            var pretty = false
            var cursor = PDKKitCLIArgumentCursor(arguments: arguments)
            while let argument = cursor.next() {
                switch argument {
                case "--manifest": manifestPath = try cursor.requireValue(for: argument)
                case "--asset-id": assetID = try cursor.requireValue(for: argument)
                case "--format":
                    let raw = try cursor.requireValue(for: argument)
                    guard let parsed = PDKStandardViewFormat(rawValue: raw.lowercased()) else {
                        throw PDKKitCLIError.invalidArguments("Unknown standard-view format: \(raw)")
                    }
                    format = parsed
                case "--run-id": runID = try cursor.requireValue(for: argument)
                case "--pretty": pretty = true
                default: throw PDKKitCLIError.invalidArguments("Unknown argument for inspect-view: \(argument)")
                }
            }
            guard let manifestPath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --manifest")
            }
            guard let assetID, !assetID.isEmpty else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --asset-id")
            }
            guard let format else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --format")
            }
            self.manifestPath = manifestPath
            self.assetID = assetID
            self.format = format
            self.runID = runID
            self.pretty = pretty
        }
    }

    func execute(options: Options) async throws -> PDKKitCLIInvocationResult {
        let manifestURL = URL(filePath: options.manifestPath).standardizedFileURL
        let pdk: PDKReference
        do {
            pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        } catch {
            throw PDKKitCLIError.invalidJSON(path: manifestURL.path, reason: String(describing: error))
        }
        let request = PDKManifestViewInspectionRequest(
            runID: options.runID,
            inputs: [pdk.manifest.locator],
            pdk: pdk,
            assetID: options.assetID,
            format: options.format
        )
        let result = try await LocalPDKManifestViewInspector().execute(request)
        let output = PDKKitStandardViewOutput(
            command: "inspect-view",
            manifestPath: manifestURL.path,
            assetID: options.assetID,
            format: options.format,
            runID: options.runID,
            status: result.status,
            diagnostics: result.diagnostics,
            payload: result.payload
        )
        let exitCode: Int32 = result.status == .completed ? 0 : 2
        return PDKKitCLIInvocationResult(
            exitCode: exitCode,
            standardOutput: try PDKKitCLIJSONCoding.encode(output, pretty: options.pretty) + "\n",
            standardError: ""
        )
    }
}
