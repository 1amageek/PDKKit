import Foundation
import PDKValidation

struct PDKKitCorpusCommand: Sendable {
    struct Options: Sendable, Equatable {
        var suitePath: String
        var rootPath: String
        var runID: String
        var pretty: Bool

        init(arguments: [String]) throws {
            var suitePath: String?
            var rootPath: String?
            var runID = "pdk-corpus-validation"
            var pretty = false
            var cursor = PDKKitCLIArgumentCursor(arguments: arguments)
            while let argument = cursor.next() {
                switch argument {
                case "--suite": suitePath = try cursor.requireValue(for: argument)
                case "--root": rootPath = try cursor.requireValue(for: argument)
                case "--run-id": runID = try cursor.requireValue(for: argument)
                case "--pretty": pretty = true
                default: throw PDKKitCLIError.invalidArguments("Unknown argument for corpus: \(argument)")
                }
            }
            guard let suitePath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --suite")
            }
            guard let rootPath else {
                throw PDKKitCLIError.invalidArguments("Missing required argument: --root")
            }
            self.suitePath = suitePath
            self.rootPath = rootPath
            self.runID = runID
            self.pretty = pretty
        }
    }

    func execute(options: Options) async throws -> PDKKitCLIInvocationResult {
        let suiteURL = URL(filePath: options.suitePath).standardizedFileURL
        let rootURL = URL(filePath: options.rootPath).standardizedFileURL
        let request = PDKCorpusValidationRequest(
            runID: options.runID,
            suitePath: suiteURL.path,
            rootPath: rootURL.path
        )
        let envelope = try await LocalPDKCorpusValidator().execute(request)
        let output = PDKKitCorpusOutput(
            command: "corpus",
            suitePath: suiteURL.path,
            rootPath: rootURL.path,
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
