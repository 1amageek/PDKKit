import Foundation
import PDKKitCLICore

@main
struct PDKKitCLIEntry {
    static func main() async {
        let exitCode = await PDKKitCLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
        Foundation.exit(exitCode)
    }
}
