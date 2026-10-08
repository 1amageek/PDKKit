import PDKDiscovery
import PDKSourceCapture
import CircuiteFoundation
import CircuiteFoundationFoundation
import Foundation
import PDKCore
import PDKValidation

struct PDKKitValidateCommand: Sendable {
    struct Options: Sendable, Equatable {
        var manifestPath: String
        var runID: String
        var requiredAssetRoles: [PDKAssetRole]
        var requiredCornerIDs: [String]
        var requireAssetIdentity: Bool
        var validateCrossViews: Bool
        var validateStandardViews: Bool
        var validateRuleDecks: Bool
        var pretty: Bool

        init(arguments: [String]) throws {
            var manifestPath: String?
            var runID = "pdk-validation"
            var requiredAssetRoles: [PDKAssetRole] = []
            var requiredCornerIDs: [String] = []
            var requireAssetIdentity = false
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
                case "--required-corner":
                    requiredCornerIDs.append(try cursor.requireValue(for: argument))
                case "--require-asset-identity": requireAssetIdentity = true
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
            self.requiredCornerIDs = requiredCornerIDs
            self.requireAssetIdentity = requireAssetIdentity
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
            reference = try await LocalPDKManifestLoader().discover(at: ArtifactLocator(location: ArtifactLocation(fileURL: url), role: .input, kind: .technology, format: .json), relativeTo: nil, captureBudget: PDKSourceCapturePolicy.defaultBudget).reference
        } catch let error as PDKManifestLoadingError {
            throw PDKKitCLIError.manifestLoading(error)
        } catch {
            throw PDKKitCLIError.invalidJSON(path: options.manifestPath, reason: String(describing: error))
        }
        let request = PDKValidationRequest(
            runID: options.runID,
            inputs: [reference.manifestLocator],
            pdk: reference,
            requiredAssetRoles: options.requiredAssetRoles,
            requiredCornerIDs: options.requiredCornerIDs,
            requireAssetIdentity: options.requireAssetIdentity,
            validateCrossViews: options.validateCrossViews,
            validateStandardViews: options.validateStandardViews,
            validateRuleDecks: options.validateRuleDecks
        )
        let result = try await LocalPDKValidator().execute(request)
        let output = PDKKitValidationOutput(
            command: "validate",
            manifestPath: url.path,
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
