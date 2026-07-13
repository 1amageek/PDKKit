import Foundation

public enum PDKKitCLI {
    public static func run(arguments: [String]) async -> Int32 {
        let result = await invoke(arguments: arguments)
        if !result.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(result.standardOutput.utf8))
        }
        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
        }
        return result.exitCode
    }

    public static func invoke(arguments: [String]) async -> PDKKitCLIInvocationResult {
        do {
            return try await dispatch(arguments: arguments)
        } catch let error as PDKKitCLIError {
            return failureResult(error)
        } catch {
            return failureResult(.internalError(String(describing: error)))
        }
    }

    private static func dispatch(arguments: [String]) async throws -> PDKKitCLIInvocationResult {
        guard let command = arguments.first else {
            throw PDKKitCLIError.invalidArguments("Missing command. Run 'pdkkit --help' for usage.")
        }
        let commandArguments = Array(arguments.dropFirst())
        switch command {
        case "--help", "-h", "help": return helpResult(generalHelp)
        case "inspect":
            if commandArguments.contains("--help") { return helpResult(inspectHelp) }
            return try PDKKitInspectCommand().execute(options: PDKKitInspectCommand.Options(arguments: commandArguments))
        case "validate":
            if commandArguments.contains("--help") { return helpResult(validateHelp) }
            return try await PDKKitValidateCommand().execute(options: PDKKitValidateCommand.Options(arguments: commandArguments))
        case "discover":
            if commandArguments.contains("--help") { return helpResult(discoverHelp) }
            return try await PDKKitDiscoverCommand().execute(options: PDKKitDiscoverCommand.Options(arguments: commandArguments))
        case "corpus":
            if commandArguments.contains("--help") { return helpResult(corpusHelp) }
            return try await PDKKitCorpusCommand().execute(options: PDKKitCorpusCommand.Options(arguments: commandArguments))
        case "inspect-view":
            if commandArguments.contains("--help") { return helpResult(inspectViewHelp) }
            return try await PDKKitInspectViewCommand().execute(options: PDKKitInspectViewCommand.Options(arguments: commandArguments))
        case "inspect-rule-deck":
            if commandArguments.contains("--help") { return helpResult(inspectRuleDeckHelp) }
            return try await PDKKitInspectRuleDeckCommand().execute(options: PDKKitInspectRuleDeckCommand.Options(arguments: commandArguments))
        case "oracle":
            if commandArguments.contains("--help") { return helpResult(oracleHelp) }
            return try await PDKKitOracleCommand().execute(options: PDKKitOracleCommand.Options(arguments: commandArguments))
        case "qualify":
            if commandArguments.contains("--help") { return helpResult(qualifyHelp) }
            return try PDKKitQualificationCommand().execute(options: PDKKitQualificationCommand.Options(arguments: commandArguments))
        default:
            throw PDKKitCLIError.invalidArguments("Unknown command: \(command). Run 'pdkkit --help' for usage.")
        }
    }

    private static func helpResult(_ text: String) -> PDKKitCLIInvocationResult {
        PDKKitCLIInvocationResult(exitCode: 0, standardOutput: text + "\n", standardError: "")
    }

    private static func failureResult(_ error: PDKKitCLIError) -> PDKKitCLIInvocationResult {
        let envelope = PDKKitCLIDiagnosticEnvelope(code: error.code, message: error.message)
        let serialized: String
        do {
            serialized = try PDKKitCLIJSONCoding.encode(envelope, pretty: false)
        } catch {
            serialized = "{\"code\":\"pdkkit.cli.internal-error\",\"message\":\"failed to encode diagnostic\"}"
        }
        return PDKKitCLIInvocationResult(exitCode: 1, standardOutput: "", standardError: serialized + "\n")
    }

    static let generalHelp = """
    OVERVIEW: Headless PDK discovery, inspection and validation.

    USAGE:
      pdkkit inspect --manifest <path> [--pretty]
      pdkkit validate --manifest <path> [--run-id <id>] [--required-role <role>] [--no-cross-view] [--no-standard-views] [--no-rule-decks] [--pretty]
      pdkkit discover --root <path> [--root <path> ...] [--process-id <id>] [--pretty]
      pdkkit corpus --suite <path> --root <path> [--run-id <id>] [--pretty]
      pdkkit inspect-view --manifest <path> --asset-id <id> --format <lef|gdsii|oasis|spice|liberty> [--run-id <id>] [--pretty]
      pdkkit inspect-rule-deck --manifest <path> --asset-id <id> [--run-id <id>] [--pretty]
      pdkkit oracle --manifest <path> --oracle <path> [--run-id <id>] [--pretty]
      pdkkit qualify --manifest <path> --corpus <path> --oracle <path> [--run-id <id>] [--pretty]

    EXIT CODES:
      0  completed validation or at least one discovery candidate
      2  blocked or failed domain validation
      1  invalid arguments, unreadable file, or invalid JSON
    """

    static let inspectHelp = """
    OVERVIEW: Decode and inspect one PDK manifest.
    USAGE: pdkkit inspect --manifest <path> [--pretty]
    """

    static let validateHelp = """
    OVERVIEW: Validate one PDK manifest, its assets, hashes and cross-view contract.
    USAGE: pdkkit validate --manifest <path> [--run-id <id>] [--required-role <role>] [--no-cross-view] [--no-standard-views] [--no-rule-decks] [--pretty]
    """

    static let discoverHelp = """
    OVERVIEW: Discover local PDK manifests without claiming semantic qualification.
    USAGE: pdkkit discover --root <path> [--root <path> ...] [--process-id <id>] [--pretty]
    """

    static let corpusHelp = """
    OVERVIEW: Evaluate a retained PDK corpus suite against the local validator.
    USAGE: pdkkit corpus --suite <path> --root <path> [--run-id <id>] [--pretty]
    """

    static let inspectViewHelp = """
    OVERVIEW: Parse a standard-view asset and bind its semantics to a PDK manifest.
    USAGE: pdkkit inspect-view --manifest <path> --asset-id <id> --format <lef|gdsii|oasis|spice|liberty> [--run-id <id>] [--pretty]
    """

    static let inspectRuleDeckHelp = """
    OVERVIEW: Parse a rule-deck asset and bind mapped layer evidence to a PDK manifest.
    USAGE: pdkkit inspect-rule-deck --manifest <path> --asset-id <id> [--run-id <id>] [--pretty]
    """

    static let oracleHelp = """
    OVERVIEW: Compare manifest-bound standard-view semantics against an immutable oracle expectation.
    USAGE: pdkkit oracle --manifest <path> --oracle <path> [--run-id <id>] [--pretty]
    """

    static let qualifyHelp = """
    OVERVIEW: Gate a PDK for local oracle correlation using retained corpus and oracle reports.
    USAGE: pdkkit qualify --manifest <path> --corpus <path> --oracle <path> [--run-id <id>] [--pretty]
    """
}
