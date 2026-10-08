import Foundation
import PDKDiscovery

public enum PDKKitCLI {
    public static func run(arguments: [String], argumentStart: Int = 0) async -> Int32 {
        if argumentStart >= 0, argumentStart < arguments.count, arguments[argumentStart] == "profile" {
            return await NativePDKProfileCommand().execute(arguments: arguments, argumentStart: argumentStart,
                standardOutput: NativePDKProfileOutputSink(descriptor: 1),
                standardError: NativePDKProfileOutputSink(descriptor: 2)).exitCode
        }
        guard argumentStart >= 0, argumentStart <= arguments.count else { return 1 }
        if argumentStart > 0 { return await run(arguments: Array(arguments.dropFirst(argumentStart))) }
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
        if arguments.first == "profile" {
            let result = await NativePDKProfileCommand().execute(arguments: arguments,
                standardOutput: PDKProfileMemoryOutputSink(), standardError: PDKProfileMemoryOutputSink())
            return .init(profileResult: result)
        }
        do {
            return try await dispatch(arguments: arguments)
        } catch let error as PDKManifestLoadingError {
            return failureResult(.manifestLoading(error))
        } catch let error as PDKKitCLIError {
            return failureResult(error)
        } catch {
            return failureResult(.internalError(String(describing: error)))
        }
    }

    private static func dispatch(arguments: [String]) async throws -> PDKKitCLIInvocationResult {
        guard let command = arguments.first else {
            throw PDKKitCLIError.invalidArguments("Missing command. Run 'pdkkit-cli --help' for usage.")
        }
        let commandArguments = Array(arguments.dropFirst())
        switch command {
        case "--help", "-h", "help": return helpResult(generalHelp)
        case "inspect":
            if commandArguments.contains("--help") { return helpResult(inspectHelp) }
            return try await PDKKitInspectCommand().execute(options: PDKKitInspectCommand.Options(arguments: commandArguments))
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
        default:
            throw PDKKitCLIError.invalidArguments("Unknown command: \(command). Run 'pdkkit-cli --help' for usage.")
        }
    }

    private static func helpResult(_ text: String) -> PDKKitCLIInvocationResult {
        PDKKitCLIInvocationResult(exitCode: 0, standardOutput: text + "\n", standardError: "")
    }

    private static func failureResult(_ error: PDKKitCLIError) -> PDKKitCLIInvocationResult {
        let result = PDKKitCLIDiagnosticOutput(code: error.code, message: error.message)
        let serialized: String
        do {
            serialized = try PDKKitCLIJSONCoding.encode(result, pretty: false)
        } catch {
            serialized = "{\"code\":\"pdkkit.cli.internal-error\",\"message\":\"failed to encode diagnostic\"}"
        }
        return PDKKitCLIInvocationResult(exitCode: 1, standardOutput: "", standardError: serialized + "\n")
    }

    static let generalHelp = """
    OVERVIEW: Headless PDK discovery, inspection and validation.

    USAGE:
      pdkkit-cli inspect --manifest <path> [--pretty]
      pdkkit-cli validate --manifest <path> [--run-id <id>] [--required-role <role>] [--required-corner <id>] [--require-asset-identity] [--no-cross-view] [--no-standard-views] [--no-rule-decks] [--pretty]
      pdkkit-cli discover --root <path> [--root <path> ...] [--process-id <id>] [--pretty]
      pdkkit-cli corpus --suite <path> --root <path> [--run-id <id>] [--pretty]
      pdkkit-cli inspect-view --manifest <path> --asset-id <id> --format <lef|gdsii|oasis|spice|liberty> [--run-id <id>] [--pretty]
      pdkkit-cli inspect-rule-deck --manifest <path> --asset-id <id> [--run-id <id>] [--pretty]
      pdkkit-cli oracle --manifest <path> --oracle <path> [--run-id <id>] [--pretty]
      pdkkit-cli profile <propose|plan|admit|replay> --input-root <absolute directory> --input-root-id <id> --budget <relative path> --availability <relative path> --availability-sha256 <hex> --availability-bytes <UInt64>
        propose additionally: --authoring <relative path> --authoring-sha256 <hex> --authoring-bytes <UInt64>

    EXIT CODES:
      0  completed validation or at least one discovery candidate
      2  blocked or failed domain validation
      1  invalid arguments, unreadable file, or invalid JSON
    """

    static let inspectHelp = """
    OVERVIEW: Decode and inspect one PDK manifest.
    USAGE: pdkkit-cli inspect --manifest <path> [--pretty]
    """

    static let validateHelp = """
    OVERVIEW: Validate one PDK manifest, its assets, hashes and cross-view contract.
    USAGE: pdkkit-cli validate --manifest <path> [--run-id <id>] [--required-role <role>] [--required-corner <id>] [--require-asset-identity] [--no-cross-view] [--no-standard-views] [--no-rule-decks] [--pretty]
    """

    static let discoverHelp = """
    OVERVIEW: Discover local PDK manifests without claiming semantic qualification.
    USAGE: pdkkit-cli discover --root <path> [--root <path> ...] [--process-id <id>] [--pretty]
    """

    static let corpusHelp = """
    OVERVIEW: Evaluate a retained PDK corpus suite against the local validator.
    USAGE: pdkkit-cli corpus --suite <path> --root <path> [--run-id <id>] [--pretty]
    """

    static let inspectViewHelp = """
    OVERVIEW: Parse a standard-view asset and bind its semantics to a PDK manifest.
    USAGE: pdkkit-cli inspect-view --manifest <path> --asset-id <id> --format <lef|gdsii|oasis|spice|liberty> [--run-id <id>] [--pretty]
    """

    static let inspectRuleDeckHelp = """
    OVERVIEW: Parse a rule-deck asset and bind mapped layer evidence to a PDK manifest.
    USAGE: pdkkit-cli inspect-rule-deck --manifest <path> --asset-id <id> [--run-id <id>] [--pretty]
    """

    static let oracleHelp = """
    OVERVIEW: Compare manifest-bound standard-view semantics against an immutable oracle expectation.
    USAGE: pdkkit-cli oracle --manifest <path> --oracle <path> [--run-id <id>] [--pretty]
    """

}
