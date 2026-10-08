public protocol PDKProfileCommandExecuting: Sendable {
    func execute(arguments: [String], argumentStart: Int,
                 standardOutput: any PDKProfileOutputSink,
                 standardError: any PDKProfileOutputSink) async -> PDKProfileCommandResult
}
