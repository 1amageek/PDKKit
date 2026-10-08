import Foundation
import PDKCore
@testable import PDKProfileAdmission
@testable import PDKKitCLICore
import Synchronization
import Testing
import CircuiteFoundation
import CircuiteFoundationFoundation

@Suite(.timeLimit(.minutes(1)))
struct ProfileOutputTests {
    private final class Clock: PDKAdmissionExecutionClock {
        let instant = Mutex(ContinuousClock.now)
        func now() -> ContinuousClock.Instant { instant.withLock { $0 } }
        func advance(_ amount: Duration) { instant.withLock { $0 = $0.advanced(by: amount) } }
    }
    private final class Accountant: PDKAdmissionResourceAccounting {
        let native: LocalPDKAdmissionResources
        let refuseNew = Mutex(false)
        init(native: LocalPDKAdmissionResources) { self.native = native }
        func check() throws(PDKAdmissionResourceError) { try native.check() }
        func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
            guard !refuseNew.withLock({ $0 }) else { throw .unsupportedBudgetCapability("Reservation after prepared boundary") }
            return try native.reserve(cost)
        }
    }
    private final class Sink: PDKProfileOutputSink {
        enum Behavior: Sendable { case full, short, invalid, writeFailure, finishFailure, late, cancel }
        struct State { var writes = 0; var finishes = 0; var bytes: [UInt8] = [] }
        let state = Mutex(State())
        let behavior: Behavior
        let clock: Clock?
        init(_ behavior: Behavior = .full, clock: Clock? = nil) { self.behavior = behavior; self.clock = clock }
        func write(_ bytes: borrowing Span<UInt8>) throws(PDKProfileOutputSinkError) -> Int {
            state.withLock { state in
                state.writes += 1
                for index in 0..<bytes.count { state.bytes.append(bytes[index]) }
            }
            switch behavior {
            case .writeFailure: throw .writeFailed
            case .short: return bytes.count - 1
            case .invalid: return bytes.count + 1
            case .late: clock?.advance(.nanoseconds(100))
            case .cancel: withUnsafeCurrentTask { $0?.cancel() }
            default: break
            }
            return bytes.count
        }
        func finish() throws(PDKProfileOutputSinkError) {
            state.withLock { $0.finishes += 1 }
            if behavior == .finishFailure { throw .finishFailed }
        }
    }
    private struct Body: Codable, Equatable {
        let schemaVersion: Int
        let name: String
        let maximum: UInt64
        let minimum: Int64
        let floating: Double
        let values: [Bool]
        let budget: PDKAdmissionBudget
    }
    private struct DefinitionBody: Codable { let definition: PDKProfileDefinition }
    private struct SmallBody: Encodable { let schemaVersion = 1; let command = "plan" }
    private struct EmptyBody: Encodable {
        enum Keys: String, CodingKey { case unused }
        func encode(to encoder: any Encoder) throws { _ = encoder.container(keyedBy: Keys.self) }
    }

    private func budget(temporary: UInt64 = 1_000_000, work: UInt64 = 1_000_000,
                        elapsed: UInt64 = UInt64.max) throws -> PDKAdmissionBudget {
        var limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64(1_000_000)) })
        limits[.temporaryBytes] = temporary; limits[.parserWork] = work
        return try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: elapsed)
    }
    private func bootstrap(_ budget: PDKAdmissionBudget) -> PDKBudgetBootstrapResult {
        PDKBudgetBootstrapResult(budget: budget, inputByteCount: 874, scannedWorkUnitCount: 900, dimensionEntryCapacity: 21)
    }
    private func observations(_ resources: LocalPDKAdmissionResources) throws -> PDKProfileOutputObservations {
        try PDKProfileOutputObservations(snapshot: resources.snapshot(), bootstrap: bootstrap(resources.budget))
    }
    private func live(_ resources: LocalPDKAdmissionResources) throws -> UInt64 {
        let entry = try #require(resources.snapshot().dimensions.first { $0.dimension == .liveOwnedBytes })
        guard case .live(let current, _) = entry.usage else { Issue.record("Expected live bytes"); return 0 }
        return current
    }
    private func makeOutput(_ resources: LocalPDKAdmissionResources) throws -> PDKOwnedProfileOutput {
        let encoder: any PDKProfileOutputEncoding = NativePDKProfileOutputEncoder()
        let completion = try encoder.reserveCompletion(resources: resources, policy: .standard)
        let prepared = try encoder.prepare(SmallBody(), completion: completion)
        return try prepared.complete(observations: observations(resources))
    }
    private func data(_ output: PDKOwnedProfileOutput) -> Data {
        output.withBytes { bytes in
            var array: [UInt8] = []; array.reserveCapacity(bytes.count)
            for index in 0..<bytes.count { array.append(bytes[index]) }
            return Data(array)
        }
    }

    @Test func existingCoreBudgetWireAndEscapedScalarsRoundTrip() throws {
        let configured = try budget()
        let resources = LocalPDKAdmissionResources(budget: configured)
        let body = Body(schemaVersion: 1, name: "quote\" slash\\ control\u{0}\n 日本語 👩‍🔬", maximum: .max,
                        minimum: .min, floating: -Double.greatestFiniteMagnitude, values: [true, false], budget: configured)
        let encoder = NativePDKProfileOutputEncoder()
        let completion = try encoder.reserveCompletion(resources: resources)
        let prepared = try encoder.prepare(body, completion: completion)
        let output = try prepared.complete(observations: observations(resources))
        #expect(try JSONDecoder().decode(Body.self, from: data(output)) == body)
        let json = try #require(JSONSerialization.jsonObject(with: data(output)) as? [String: Any])
        let operational = try #require(json["operationalObservations"] as? [String: Any])
        #expect(operational["boundary"] as? String == "prepared-output")
        let admission = try #require(operational["admission"] as? [String: Any])
        #expect((admission["dimensions"] as? [[String: Any]])?.count == 21)
    }

    @Test func exactCheckedDefinitionCodecSchemaIsPreserved() throws {
        func reference(_ digit: String, kind: String, format: ArtifactFormat) throws -> ArtifactReference {
            try ArtifactReference(digest: ContentDigest(algorithm: .sha256, hexadecimalValue: String(repeating: digit, count: 64)),
                byteCount: 4, descriptor: ArtifactDescriptor(role: ArtifactRole(validatingRawValue: "input"), kind: ArtifactKind(rawValue: kind), format: format))
        }
        let source = try PDKProfileSource(sourceKey: "root", assetID: "model", reference: reference("1", kind: "pdk.spice", format: .spice), logicalRoutes: ["model.sp"])
        let requirement = try PDKViewRequirement(requirementID: "simulation", purposeID: "tran", view: .spice, role: .model,
            assetIDs: ["model"], cornerIDs: [], selectedSection: nil, isShared: true,
            allowsMultipleSources: false, demandedFactKinds: ["devices"])
        let definition = try PDKProfileDefinition(profileID: "demo", manifestReference: reference("a", kind: "pdk.technology", format: .json),
            processID: "p", version: "1", requiredCornerIDs: [], requirements: [requirement], sources: [source],
            orderedSearchRoutes: ["models"], dependencies: [], inspectionPolicyIdentity: "policy.v1", initialPreprocessingIdentity: "empty.v1")
        let resources = LocalPDKAdmissionResources(budget: try budget())
        let encoder = NativePDKProfileOutputEncoder()
        let completion = try encoder.reserveCompletion(resources: resources)
        let prepared = try encoder.prepare(DefinitionBody(definition: definition), completion: completion)
        let output = try prepared.complete(observations: observations(resources))
        #expect(try JSONDecoder().decode(DefinitionBody.self, from: data(output)).definition == definition)
    }

    @Test func preallocationRefusalRetainsTheAlreadyReservedTerminalFailure() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget(temporary: 32))
        let encoder = NativePDKProfileOutputEncoder()
        let completion = try encoder.reserveCompletion(resources: resources)
        do { _ = try encoder.prepare(SmallBody(), completion: completion); Issue.record("Node allocation escaped its quota") }
        catch let error as PDKProfileOutputError {
            guard case .resource(.exhausted(let dimension, _, _)) = error else { throw error }
            #expect(dimension == .temporaryBytes)
        }
        let json = try #require(JSONSerialization.jsonObject(with: data(completion.terminalOutput)) as? [String: Any])
        #expect(json["status"] as? String == "failed")
        #expect(json["reason"] as? String == "output_failure")
    }

    @Test func cumulativeWorkAcrossFieldsCannotRestartTheAccountant() throws {
        let configured = try budget()
        let resources = LocalPDKAdmissionResources(budget: configured)
        let accountant = Accountant(native: resources)
        let encoder = NativePDKProfileOutputEncoder()
        let completion = try encoder.reserveCompletion(resources: accountant)
        let before = try resources.snapshot()
        let entry = try #require(before.dimensions.first { $0.dimension == .parserWork })
        guard case .cumulative(let charged) = entry.usage else { Issue.record("Expected parser work"); return }
        _ = try accountant.reserve(PDKAdmissionCost(dimension: .parserWork, amount: entry.limit - charged - 5))
        do { _ = try encoder.prepare(SmallBody(), completion: completion); Issue.record("Work quota restarted") }
        catch let error as PDKProfileOutputError {
            guard case .resource(.exhausted(let dimension, _, _)) = error else { throw error }
            #expect(dimension == .parserWork)
        }
    }

    @Test func preparedCompletionNeverReservesAgainAndCopiedTokenCannotCompleteTwice() async throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        let accountant = Accountant(native: resources)
        let encoder = NativePDKProfileOutputEncoder()
        let completion = try encoder.reserveCompletion(resources: accountant)
        let prepared = try encoder.prepare(EmptyBody(), completion: completion)
        let copied = prepared
        let suffix = try observations(resources)
        accountant.refuseNew.withLock { $0 = true }
        let outputs = try await withThrowingTaskGroup(of: PDKOwnedProfileOutput?.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    do { return try prepared.complete(observations: suffix) }
                    catch let error as PDKProfileOutputError {
                        guard case .completionAlreadyUsed = error else { throw error }
                        return nil
                    }
                }
            }
            var values: [PDKOwnedProfileOutput] = []
            for try await value in group { if let value { values.append(value) } }
            return values
        }
        #expect(outputs.count == 1)
        let output = try #require(outputs.first)
        #expect((try JSONSerialization.jsonObject(with: data(output)) as? [String: Any])?.count == 1)
        do { _ = try copied.complete(observations: suffix); Issue.record("Copied completion spent capacity twice") }
        catch let error as PDKProfileOutputError {
            guard case .completionAlreadyUsed = error else { throw error }
        }
        let delivered = try NativePDKProfileOutputDelivery().deliver(output, to: Sink())
        #expect(delivered.output.byteCount == output.byteCount)
    }

    @Test func lastOwnedOutputCopyReleasesItsActualStorageAfterAccountantClose() throws {
        let resources = LocalPDKAdmissionResources(budget: try budget())
        var copied: PDKOwnedProfileOutput?
        do {
            let output = try makeOutput(resources)
            copied = output
            #expect(try live(resources) >= UInt64(output.byteCount))
        }
        resources.close()
        #expect(try live(resources) > 0)
        copied = nil
        #expect(try live(resources) == 0)
        withExtendedLifetime(copied) {}
    }

    @Test(arguments: [Sink.Behavior.short, .invalid, .writeFailure, .finishFailure, .late, .cancel])
    private func failedShortLateAndCancelledDeliveryCannotPublish(behavior: Sink.Behavior) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let clock = Clock()
                let resources = LocalPDKAdmissionResources(budget: try budget(elapsed: 100), clock: clock)
                let output = try makeOutput(resources)
                let sink = Sink(behavior, clock: clock)
                do { _ = try NativePDKProfileOutputDelivery().deliver(output, to: sink); Issue.record("Failed sink published checked delivery") }
                catch let error as PDKProfileOutputError {
                    switch (behavior, error) {
                    case (.short, .shortWrite), (.invalid, .shortWrite), (.writeFailure, .sink(.writeFailed)),
                         (.finishFailure, .sink(.finishFailed)), (.late, .resource(.deadlineExceeded)), (.cancel, .resource(.cancelled)): break
                    default: throw error
                    }
                }
                let state = sink.state.withLock { $0 }
                #expect(state.writes == 1)
                #expect(state.finishes == (behavior == .short || behavior == .invalid || behavior == .writeFailure ? 0 : 1))
                #expect(try live(resources) > 0)
            }
            try await group.waitForAll()
        }
    }

    @Test func fixedVocabularyMaximumWidthsFitTheDerivedCompletionPolicy() throws {
        let configured = try budget()
        let entries = PDKAdmissionResourceDimension.allCases.map {
            PDKAdmissionResourceObservation(dimension: $0, limit: .max,
                usage: $0.isLiveCapacity ? .live(current: .max, peak: .max) : .cumulative(total: .max))
        }
        let snapshot = PDKAdmissionResourceSnapshot(accountingVersion: Int.max, maximumElapsedNanoseconds: .max,
            elapsed: .nanoseconds(Int64.max), isDeadlineExceeded: false, isClosed: false, dimensions: entries)
        let bootstrap = PDKBudgetBootstrapResult(budget: configured, inputByteCount: .max, scannedWorkUnitCount: .max, dimensionEntryCapacity: Int.max)
        let suffix = try PDKProfileOutputObservations(snapshot: snapshot, bootstrap: bootstrap)
        var count = 0
        try suffix.write(hasPayloadFields: true) { _ in count += 1 }
        #expect(count <= PDKProfileOutputCompletionPolicy.standard.maximumSuffixByteCount)
        do { _ = try PDKProfileOutputCompletionPolicy(maximumSuffixByteCount: UInt64(count - 1)); Issue.record("Insufficient suffix capacity was accepted") }
        catch let error as PDKProfileOutputError { guard case .invalidCompletionPolicy = error else { throw error } }
        let oversized = PDKAdmissionResourceSnapshot(accountingVersion: 1, maximumElapsedNanoseconds: .max,
            elapsed: .seconds(Int64.max), isDeadlineExceeded: true, isClosed: true, dimensions: entries)
        do { _ = try PDKProfileOutputObservations(snapshot: oversized, bootstrap: bootstrap); Issue.record("Elapsed overflow became successful evidence") }
        catch let error as PDKProfileOutputError { guard case .elapsedOverflow = error else { throw error } }
    }

    @Test func outputStorageIsRefusedBeforeAnyPayloadBufferGrowth() throws {
        let configured = try budget()
        var limits = configured.limits
        limits[.liveOwnedBytes] = UInt64("{\"schemaVersion\":1,\"status\":\"failed\",\"reason\":\"output_failure\"}\n".utf8.count)
        let resources = LocalPDKAdmissionResources(budget: try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: .max))
        let encoder = NativePDKProfileOutputEncoder()
        let completion = try encoder.reserveCompletion(resources: resources)
        let held = try live(resources)
        do { _ = try encoder.prepare(SmallBody(), completion: completion); Issue.record("Unadmitted output storage grew") }
        catch let error as PDKProfileOutputError {
            guard case .resource(.exhausted(let dimension, _, _)) = error else { throw error }
            #expect(dimension == .liveOwnedBytes)
        }
        #expect(try live(resources) == held)
        #expect(completion.terminalOutput.byteCount == Int(held))
    }

    @Test func unsupportedFloatingValuesAndSuppressedContainerFailureRemainFailures() throws {
        struct Nonfinite: Encodable { let value = Double.infinity }
        struct Suppressing: Encodable {
            let accountant: Accountant
            enum Keys: String, CodingKey { case child }
            func encode(to encoder: any Encoder) throws {
                var parent = encoder.container(keyedBy: Keys.self)
                accountant.refuseNew.withLock { $0 = true }
                _ = parent.nestedContainer(keyedBy: Keys.self, forKey: .child)
            }
        }
        let encoder = NativePDKProfileOutputEncoder()
        let resources = LocalPDKAdmissionResources(budget: try budget())
        let completion = try encoder.reserveCompletion(resources: resources)
        do { _ = try encoder.prepare(Nonfinite(), completion: completion); Issue.record("Nonfinite JSON succeeded") }
        catch let error as PDKProfileOutputError { guard case .nonFiniteNumber = error else { throw error } }
        let native = LocalPDKAdmissionResources(budget: try budget())
        let accountant = Accountant(native: native)
        let retained = try encoder.reserveCompletion(resources: accountant)
        do { _ = try encoder.prepare(Suppressing(accountant: accountant), completion: retained); Issue.record("Suppressed resource failure succeeded") }
        catch let error as PDKProfileOutputError {
            guard case .resource(.unsupportedBudgetCapability("Reservation after prepared boundary")) = error else { throw error }
        }
    }
}
