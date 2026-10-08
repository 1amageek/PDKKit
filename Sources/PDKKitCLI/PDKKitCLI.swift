import Foundation
import PDKKitCLICore

@main
struct PDKKitCLIEntry {
    static func main() async {
        let exitCode = await PDKKitCLI.run(arguments: CommandLine.arguments, argumentStart: 1)
        Foundation.exit(exitCode)
    }
}
