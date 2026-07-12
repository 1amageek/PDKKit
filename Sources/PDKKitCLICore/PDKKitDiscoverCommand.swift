import Foundation
import PDKDiscovery
import XcircuitePackage

struct PDKKitDiscoverCommand: Sendable {
    struct Options: Sendable, Equatable {
        var searchRoots: [String]
        var requiredProcessID: String?
        var pretty: Bool

        init(arguments: [String]) throws {
            var searchRoots: [String] = []
            var requiredProcessID: String?
            var pretty = false
            var cursor = PDKKitCLIArgumentCursor(arguments: arguments)
            while let argument = cursor.next() {
                switch argument {
                case "--root": searchRoots.append(try cursor.requireValue(for: argument))
                case "--process-id": requiredProcessID = try cursor.requireValue(for: argument)
                case "--pretty": pretty = true
                default: throw PDKKitCLIError.invalidArguments("Unknown argument for discover: \(argument)")
                }
            }
            guard !searchRoots.isEmpty else {
                throw PDKKitCLIError.invalidArguments("At least one --root is required")
            }
            self.searchRoots = searchRoots
            self.requiredProcessID = requiredProcessID
            self.pretty = pretty
        }
    }

    func execute(options: Options) async throws -> PDKKitCLIInvocationResult {
        let request = PDKDiscoveryRequest(
            runID: "pdk-discovery",
            inputs: [],
            searchRoots: options.searchRoots,
            requiredProcessID: options.requiredProcessID
        )
        let envelope = try await LocalPDKDiscoverer().execute(request)
        let output = PDKKitDiscoveryOutput(
            command: "discover",
            searchRoots: options.searchRoots,
            requiredProcessID: options.requiredProcessID,
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
