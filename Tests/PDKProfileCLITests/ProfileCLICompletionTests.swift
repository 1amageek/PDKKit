import CircuiteFoundation
import Darwin
import Foundation
import PDKCore
import PDKDiscovery
import PDKKitCLICore
import PDKProfileAdmission
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ProfileCLICompletionTests {
    @Test func initialMetadataBudgetRefusalPreservesCauseAndUsesDeliveryAwareExitCode() async throws {
        let fixture = try await ProfileCLIFixture.make(jsonOnly: true)
        defer { fixture.cleanup() }
        let budget = try ProfileCLIFixture.makeBudget(overrides: [.liveOwnedBytes: 1])
        try JSONEncoder().encode(budget).write(to: fixture.root.rootURL.appending(path: "budget.json"))
        let input = InputProbe()
        let stdout = Sink(); let stderr = Sink()
        let result = await NativePDKProfileCommand(input: input).execute(arguments: fixture.arguments("propose"),
            standardOutput: stdout, standardError: stderr)
        #expect(result.exitCode == 2)
        #expect(result.output == nil)
        #expect(input.resources == nil)
        #expect(stdout.counts.writes == 0)
        #expect(stderr.counts.writes == 1)
        #expect(stderr.counts.finishes == 1)
        #expect(result.deliveryFailure == nil)
        let failure = try #require(result.failure)
        guard case .resource(let original) = failure,
              case .exhausted(dimension: .liveOwnedBytes, limit: 1, attempted: let attempted) = original else {
            Issue.record("Expected initial command-owner capacity refusal"); return
        }
        #expect(attempted > 1)

        let failedInput = InputProbe()
        let failedStdout = Sink(); let failedStderr = Sink(.failedFinish)
        let failed = await NativePDKProfileCommand(input: failedInput).execute(arguments: fixture.arguments("propose"),
            standardOutput: failedStdout, standardError: failedStderr)
        #expect(failed.exitCode == 1)
        #expect(failed.output == nil)
        #expect(failedInput.resources == nil)
        #expect(failedStdout.counts.writes == 0)
        #expect(failedStderr.counts.writes == 1)
        #expect(failedStderr.counts.finishes == 1)
        let retained = try #require(failed.failure)
        guard case .resource(let retainedCause) = retained else {
            Issue.record("Terminal delivery must preserve the original resource refusal"); return
        }
        #expect(retainedCause == original)
        let delivery = try #require(failed.deliveryFailure)
        guard case .sink(.finishFailed) = delivery else {
            Issue.record("Expected terminal finish failure alongside resource refusal"); return
        }
    }

    final class InputProbe: PDKProfileCLIInputLoading {
        private let state = Mutex<(any PDKAdmissionResourceAccounting)?>(nil)
        private let native = NativePDKProfileCLIInputLoader()
        var resources: (any PDKAdmissionResourceAccounting)? { state.withLock { $0 } }
        func loadBudget(root: PDKProfileAuthorizedRoot, relativePath: ArtifactRelativePath,
                        policy: PDKBudgetBootstrapPolicy, accessBudget: ArtifactAccessBudget)
            async throws(PDKProfileCLIInputError) -> PDKLoadedBudgetBootstrap {
            try await native.loadBudget(root: root, relativePath: relativePath, policy: policy, accessBudget: accessBudget)
        }
        func loadAvailability(binding: PDKProfileExactBinding, root: PDKProfileAuthorizedRoot,
                              resources: any PDKAdmissionResourceAccounting)
            async throws(PDKProfileCLIInputError) -> PDKDecodedDocument<PDKProfileCLIAvailability> {
            state.withLock { $0 = resources }
            return try await native.loadAvailability(binding: binding, root: root, resources: resources)
        }
        func loadAuthoring(binding: PDKProfileExactBinding, root: PDKProfileAuthorizedRoot,
                           resources: any PDKAdmissionResourceAccounting)
            async throws(PDKProfileCLIInputError) -> PDKDecodedDocument<PDKProfileCLIAuthoring> {
            state.withLock { $0 = resources }
            return try await native.loadAuthoring(binding: binding, root: root, resources: resources)
        }
    }

    private func liveBytes(_ resources: LocalPDKAdmissionResources) throws -> UInt64 {
        let snapshot = try resources.snapshot()
        let observation = try #require(snapshot.dimensions.first { $0.dimension == .liveOwnedBytes })
        guard case .live(let current, _) = observation.usage else {
            Issue.record("The live-owned dimension must retain live capacity observations")
            return 0
        }
        return current
    }

    @Test func completedInvocationClosesAccountantAndRetainsOwnersUntilLastResultCopy() async throws {
        let fixture = try await ProfileCLIFixture.make(jsonOnly: true)
        defer { fixture.cleanup() }
        let input = InputProbe()
        var result: PDKProfileCommandResult? = await NativePDKProfileCommand(input: input).execute(
            arguments: fixture.arguments("propose"), standardOutput: Sink(), standardError: Sink())
        #expect(result?.exitCode == 0)
        let resources = try #require(input.resources as? LocalPDKAdmissionResources)
        #expect(try resources.snapshot().isClosed)
        let retained = try liveBytes(resources)
        #expect(retained > 0)
        var copy = result
        result = nil
        #expect(copy?.exitCode == 0)
        #expect(try liveBytes(resources) == retained)
        withExtendedLifetime(copy) {}
        copy = nil
        #expect(try liveBytes(resources) == 0)
    }

    @Test func nativeClosedPipeReturnsTypedWriteFailureWithoutSignalTermination() throws {
        var descriptors = [Int32](repeating: -1, count: 2)
        let created = descriptors.withUnsafeMutableBufferPointer { Darwin.pipe($0.baseAddress!) }
        try #require(created == 0)
        defer { #expect(Darwin.close(descriptors[1]) == 0) }
        try #require(Darwin.close(descriptors[0]) == 0)
        let sink = NativePDKProfileOutputSink(descriptor: descriptors[1])
        let bytes: [UInt8] = [123, 125, 10]
        do throws(PDKProfileOutputSinkError) {
            _ = try sink.write(bytes.span)
            Issue.record("A pipe without a reader must refuse the native write")
        } catch {
            #expect(error == .writeFailed)
        }
    }

    final class Clock: PDKAdmissionExecutionClock {
        private let instant = Mutex(ContinuousClock().now)
        func now() -> ContinuousClock.Instant { instant.withLock { $0 } }
        func expire() { instant.withLock { $0 = $0.advanced(by: .seconds(31)) } }
    }

    final class Sink: PDKProfileOutputSink {
        enum Behavior: Sendable, Equatable { case normal, shortWrite, failedFinish, expireOnFinish }
        struct Counts { var writes = 0; var finishes = 0; var bytes = 0 }
        let behavior: Behavior
        let clock: Clock?
        private let state = Mutex(Counts())
        init(_ behavior: Behavior = .normal, clock: Clock? = nil) {
            self.behavior = behavior; self.clock = clock
        }
        var counts: Counts { state.withLock { $0 } }
        func write(_ bytes: borrowing Span<UInt8>) throws(PDKProfileOutputSinkError) -> Int {
            state.withLock { $0.writes += 1; $0.bytes += bytes.count }
            return behavior == .shortWrite ? max(0, bytes.count - 1) : bytes.count
        }
        func finish() throws(PDKProfileOutputSinkError) {
            state.withLock { $0.finishes += 1 }
            if behavior == .failedFinish { throw .finishFailed }
            if behavior == .expireOnFinish { clock?.expire() }
        }
    }

    @Test func shortNativeSinkWriteCannotCompleteProfileCommand() async throws {
        let fixture = try await ProfileCLIFixture.make()
        defer { fixture.cleanup() }
        let stdout = Sink(.shortWrite); let stderr = Sink()
        let result = await NativePDKProfileCommand().execute(arguments: fixture.arguments("propose"),
            standardOutput: stdout, standardError: stderr)
        #expect(result.exitCode != 0)
        let failure = try #require(result.deliveryFailure)
        guard case .shortWrite(let expected, let actual) = failure else {
            Issue.record("Expected exact short-write delivery failure"); return
        }
        #expect(expected == actual + 1)
        #expect(stdout.counts.writes == 1)
        #expect(stdout.counts.finishes == 0)
    }

    @Test func nativeSinkFinishFailureCannotCompleteProfileCommand() async throws {
        let fixture = try await ProfileCLIFixture.make()
        defer { fixture.cleanup() }
        let stdout = Sink(.failedFinish); let stderr = Sink()
        let result = await NativePDKProfileCommand().execute(arguments: fixture.arguments("propose"),
            standardOutput: stdout, standardError: stderr)
        #expect(result.exitCode != 0)
        let failure = try #require(result.deliveryFailure)
        guard case .sink(.finishFailed) = failure else {
            Issue.record("Expected retained typed finish failure"); return
        }
        #expect(stdout.counts.writes == 1)
        #expect(stdout.counts.finishes == 1)
    }

    @Test func deadlineAfterActualDeliveryMakesWrittenEnvelopeProvisional() async throws {
        let fixture = try await ProfileCLIFixture.make()
        defer { fixture.cleanup() }
        let clock = Clock()
        let stdout = Sink(.expireOnFinish, clock: clock); let stderr = Sink()
        let result = await NativePDKProfileCommand(clock: clock).execute(arguments: fixture.arguments("propose"),
            standardOutput: stdout, standardError: stderr)
        #expect(result.exitCode != 0)
        let failure = try #require(result.deliveryFailure)
        guard case .resource = failure else {
            Issue.record("Expected post-delivery deadline failure"); return
        }
        #expect(stdout.counts.writes == 1)
        #expect(stdout.counts.finishes == 1)
        #expect(stdout.counts.bytes > 0)
    }
}
