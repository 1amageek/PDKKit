import Foundation
import PDKCore
import PDKStandardViews

struct PDKKitInspectRuleDeckCommand: Sendable {
    struct Options: Sendable, Equatable {
        var manifestPath: String
        var assetID: String
        var runID: String
        var pretty: Bool

        init(arguments: [String]) throws {
            var manifestPath: String?
            var assetID: String?
            var runID = "pdk-rule-deck-inspection"
            var pretty = false
            var cursor = PDKKitCLIArgumentCursor(arguments: arguments)
            while let argument = cursor.next() {
                switch argument {
                case "--manifest": manifestPath = try cursor.requireValue(for: argument)
                case "--asset-id": assetID = try cursor.requireValue(for: argument)
                case "--run-id": runID = try cursor.requireValue(for: argument)
                case "--pretty": pretty = true
                default: throw PDKKitCLIError.invalidArguments("Unknown argument for inspect-rule-deck: \(argument)")
                }
            }
            guard let manifestPath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --manifest")
            }
            guard let assetID, !assetID.isEmpty else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --asset-id")
            }
            self.manifestPath = manifestPath
            self.assetID = assetID
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
        let request = PDKRuleDeckInspectionRequest(
            runID: options.runID,
            inputs: [pdk.manifest],
            pdk: pdk,
            assetID: options.assetID
        )
        let envelope = try await LocalPDKRuleDeckInspector().execute(request)
        let output = PDKKitRuleDeckOutput(
            command: "inspect-rule-deck",
            manifestPath: manifestURL.path,
            assetID: options.assetID,
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
}
