import Foundation
import PDKCore
import PDKValidation
import XcircuitePackage

struct PDKKitValidateCommand: Sendable {
    struct Options: Sendable, Equatable {
        var manifestPath: String
        var runID: String
        var requiredAssetRoles: [PDKAssetRole]
        var validateCrossViews: Bool
        var validateStandardViews: Bool
        var validateRuleDecks: Bool
        var pretty: Bool

        init(arguments: [String]) throws {
            var manifestPath: String?
            var runID = "pdk-validation"
            var requiredAssetRoles: [PDKAssetRole] = []
            var validateCrossViews = true
            var validateStandardViews = true
            var validateRuleDecks = true
            var pretty = false
            var cursor = PDKKitCLIArgumentCursor(arguments: arguments)
            while let argument = cursor.next() {
                switch argument {
                case "--manifest": manifestPath = try cursor.requireValue(for: argument)
                case "--run-id": runID = try cursor.requireValue(for: argument)
                case "--required-role":
                    let raw = try cursor.requireValue(for: argument)
                    guard let role = PDKAssetRole(rawValue: raw) else {
                        throw PDKKitCLIError.invalidArguments("Unknown PDK asset role: \(raw)")
                    }
                    requiredAssetRoles.append(role)
                case "--no-cross-view": validateCrossViews = false
                case "--no-standard-views": validateStandardViews = false
                case "--no-rule-decks": validateRuleDecks = false
                case "--pretty": pretty = true
                default: throw PDKKitCLIError.invalidArguments("Unknown argument for validate: \(argument)")
                }
            }
            guard let manifestPath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --manifest")
            }
            self.manifestPath = manifestPath
            self.runID = runID
            self.requiredAssetRoles = requiredAssetRoles
            self.validateCrossViews = validateCrossViews
            self.validateStandardViews = validateStandardViews
            self.validateRuleDecks = validateRuleDecks
            self.pretty = pretty
        }
    }

    func execute(options: Options) async throws -> PDKKitCLIInvocationResult {
        let url = URL(filePath: options.manifestPath).standardizedFileURL
        let reference: PDKReference
        do {
            reference = try PDKManifestReferenceBuilder().makeReference(for: url)
        } catch {
            throw PDKKitCLIError.invalidJSON(path: options.manifestPath, reason: String(describing: error))
        }
        let request = PDKValidationRequest(
            runID: options.runID,
            inputs: [reference.manifest],
            pdk: reference,
            requiredAssetRoles: options.requiredAssetRoles,
            validateCrossViews: options.validateCrossViews,
            validateStandardViews: options.validateStandardViews,
            validateRuleDecks: options.validateRuleDecks
        )
        let envelope = try await LocalPDKValidator().execute(request)
        let output = PDKKitValidationOutput(
            command: "validate",
            manifestPath: url.path,
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
