import Foundation
import PDKCore
import PDKValidation
import PDKStandardViews
import CircuiteFoundation

struct PDKKitQualificationCommand: Sendable {
    struct Options: Sendable, Equatable {
        var manifestPath: String
        var corpusPath: String
        var oraclePath: String
        var runID: String
        var pretty: Bool

        init(arguments: [String]) throws {
            var manifestPath: String?
            var corpusPath: String?
            var oraclePath: String?
            var runID = "pdk-qualification-gate"
            var pretty = false
            var cursor = PDKKitCLIArgumentCursor(arguments: arguments)
            while let argument = cursor.next() {
                switch argument {
                case "--manifest": manifestPath = try cursor.requireValue(for: argument)
                case "--corpus": corpusPath = try cursor.requireValue(for: argument)
                case "--oracle": oraclePath = try cursor.requireValue(for: argument)
                case "--run-id": runID = try cursor.requireValue(for: argument)
                case "--pretty": pretty = true
                default: throw PDKKitCLIError.invalidArguments("Unknown argument for qualify: \(argument)")
                }
            }
            guard let manifestPath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --manifest")
            }
            guard let corpusPath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --corpus")
            }
            guard let oraclePath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --oracle")
            }
            self.manifestPath = manifestPath
            self.corpusPath = corpusPath
            self.oraclePath = oraclePath
            self.runID = runID
            self.pretty = pretty
        }
    }

    func execute(options: Options) throws -> PDKKitCLIInvocationResult {
        let manifestURL = URL(filePath: options.manifestPath).standardizedFileURL
        let pdk: PDKReference
        do {
            pdk = try PDKManifestReferenceBuilder().makeReference(for: manifestURL)
        } catch {
            throw PDKKitCLIError.invalidJSON(path: manifestURL.path, reason: String(describing: error))
        }
        let corpus: PDKKitCorpusOutput = try PDKKitCLIJSONCoding.decode(
            PDKKitCorpusOutput.self,
            atPath: options.corpusPath
        )
        let oracle: PDKKitOracleOutput = try PDKKitCLIJSONCoding.decode(
            PDKKitOracleOutput.self,
            atPath: options.oraclePath
        )
        let assessment = PDKQualificationGate().evaluate(
            pdk: pdk,
            corpus: corpus.payload,
            oracle: oracle.payload
        )
        let findings = assessment.findings.map(PDKValidationDiagnosticMapper.map)
        let status: PDKExecutionStatus = assessment.isValid ? .completed : .blocked
        let output = PDKKitQualificationOutput(
            command: "qualify",
            manifestPath: manifestURL.path,
            corpusPath: URL(filePath: options.corpusPath).standardizedFileURL.path,
            oraclePath: URL(filePath: options.oraclePath).standardizedFileURL.path,
            runID: options.runID,
            status: status,
            diagnostics: findings,
            assessment: assessment
        )
        return PDKKitCLIInvocationResult(
            exitCode: assessment.isValid ? 0 : 2,
            standardOutput: try PDKKitCLIJSONCoding.encode(output, pretty: options.pretty) + "\n",
            standardError: ""
        )
    }
}
