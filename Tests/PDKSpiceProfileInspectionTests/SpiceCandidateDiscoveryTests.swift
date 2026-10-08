import CircuiteFoundation
import CoreSpiceIO
import PDKCore
import PDKProfileAdmission
@testable import PDKSpiceProfileInspection
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SpiceCandidateDiscoveryTests {
    @Test func initialIdentityNeedsNoSPICESourceAndOwnsCoreReceipts() async throws {
        let resources = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget())
        defer { resources.close() }
        let provider: any PDKSpiceCandidateDiscovering = LocalPDKSpiceCandidateDiscoverer(policyIdentity: SpiceProfileFixture.policy)
        _ = try resources.reserve(PDKAdmissionCost(dimension: .hashedBytes, amount: 1))
        var identity: PDKSpiceInitialPreprocessingIdentity? = try provider.initialPreprocessingIdentity(resources: resources)
        var expected: SPICEPreprocessingEnvironment? = try SPICEPreprocessingEnvironment.empty(
            policyIdentity: SpiceProfileFixture.policy, configuration: .init(resolveIncludes: true),
            resources: PDKSpiceResourceBridge(resources: resources), maximumPageByteCount: 4096)
        #expect(identity?.identity == expected?.identity)
        expected = nil
        var retained = identity
        identity = nil
        #expect(retained?.identity.hasPrefix("sha256:") == true)
        let snapshot = try resources.snapshot()
        #expect(snapshot.dimensions.first { $0.dimension == .readBytes }?.usage == .cumulative(total: 0))
        let hashObservation = try #require(snapshot.dimensions.first { $0.dimension == .hashedBytes })
        if case .cumulative(let hashes) = hashObservation.usage {
            #expect(hashes > 1)
        } else { Issue.record("Cumulative hash evidence lost") }
        let liveObservation = try #require(snapshot.dimensions.first { $0.dimension == .liveOwnedBytes })
        if case .live(let current, _) = liveObservation.usage {
            #expect(current > 0)
        } else { Issue.record("Live receipt evidence lost") }
        retained = nil
        let released = try resources.snapshot()
        let releasedObservation = try #require(released.dimensions.first { $0.dimension == .liveOwnedBytes })
        if case .live(let current, _) = releasedObservation.usage {
            #expect(current == 0)
        } else { Issue.record("Live receipt evidence lost") }
        let limited = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget(overrides: [.hashedBytes: 1]))
        defer { limited.close() }
        do { _ = try provider.initialPreprocessingIdentity(resources: limited); Issue.record("Hash quota ignored") }
        catch let error as PDKSpiceCandidateDiscoveryError {
            if case .resource(.exhausted(let dimension, _, _)) = error { #expect(dimension == .hashedBytes) }
            else { Issue.record("Hash quota cause lost") }
        }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try provider.initialPreprocessingIdentity(resources: resources)
        }
        await #expect(throws: PDKSpiceCandidateDiscoveryError.resource(.cancelled)) { try await task.value }
    }
    @Test func nestedRepeatedGraphIsObservedWithoutExactSeed() async throws {
        let fixture = try SpiceCandidateFixture.make(files: [
            "root": "* root\n.include child.sp\n.include child.sp\n",
            "child": "* child\n.include grand.sp\n.model c D\n", "grand": "* grand\n.model g D\n"])
        defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget()); defer { resources.close() }
        let graph = try await fixture.discover(resources: resources)
        #expect(graph.dependencies.map(\.lexicalOrder) == [1, 2, 3, 4])
        #expect(graph.dependencies.map(\.parentSourceKey) == ["root", "child", "root", "child"])
        #expect(graph.dependencies.map(\.childSourceKey) == ["child", "grand", "child", "grand"])
        #expect(graph.dependencies.map(\.statementByteOffset) == [7, 8, 25, 8])
        #expect(graph.dependencies.map(\.statementOrdinal) == [0, 0, 1, 0])
        #expect(graph.sources.map { $0.source.sourceKey } == ["root", "child", "grand"])
        #expect(graph.occurrences.map(\.occurrenceID) == [0, 1, 2, 3, 4])
        #expect(graph.occurrences.map(\.parentOccurrenceID) == [nil, 0, 1, 0, 3])
        let usage = try #require(resources.snapshot().dimensions.first { $0.dimension == .readBytes })
        #expect(usage.usage == .cumulative(total: fixture.totalByteCount))
        let environment = try SPICEPreprocessingEnvironment.empty(policyIdentity: SpiceProfileFixture.policy,
            configuration: .init(resolveIncludes: true), resources: PDKSpiceResourceBridge(resources: resources), maximumPageByteCount: 4096)
        #expect(graph.initialPreprocessingIdentity == environment.identity)
        #expect(graph.dependencies.allSatisfy { $0.preprocessingIdentity == environment.identity })
        #expect(graph.sources.allSatisfy { $0.source.reference == $0.capture.reference })
    }
    @Test func conditionalChildUsesActualInheritedEntryAndSkipsMissingInactiveRoute() async throws {
        let fixture = try SpiceCandidateFixture.make(files: [
            "root": "* root\n.param enabled=1\n.include child.sp\n",
            "child": "* child\n.if (enabled)\n.model inherited D\n.else\n.include absent.sp\n.endif\n"])
        defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget()); defer { resources.close() }
        let graph = try await fixture.discover(resources: resources)
        let expected = try SPICEPreprocessingEnvironment.admit(parameters: [.init(name: "enabled", expression: "1.0")],
            policyIdentity: SpiceProfileFixture.policy, configuration: .init(resolveIncludes: true),
            resources: PDKSpiceResourceBridge(resources: resources), maximumPageByteCount: 4096)
        #expect(graph.dependencies.count == 1)
        #expect(graph.dependencies[0].statementOrdinal == 1)
        #expect(graph.dependencies[0].preprocessingIdentity == expected.identity)
        #expect(graph.occurrences[1].preprocessingIdentity == expected.identity)
        #expect(graph.occurrences[1].inactiveStatementOffsets == [41, 66])
    }
    @Test func multipleSelectedEntryContextsOwnOneGlobalEdgeSequence() async throws {
        let fixture = try SpiceCandidateFixture.make(files: [
            "root": "* root\n.lib TT\n.include child.sp\n.endl TT\n.lib SS\n.include child.sp\n.endl SS\n",
            "child": "* child\n.model c D\n"], entries: [
                .init(sourceKey: "root", logicalRoute: "root.sp", selectedSection: "TT"),
                .init(sourceKey: "root", logicalRoute: "root.sp", selectedSection: "SS")])
        defer { fixture.remove() }
        let graph = try await fixture.discover()
        #expect(graph.sources.count == 2)
        #expect(graph.dependencies.map(\.lexicalOrder) == [1, 2])
        #expect(graph.dependencies.map(\.statementByteOffset) == [15, 50])
        #expect(graph.dependencies.allSatisfy { $0.selectedSection == nil })
        #expect(graph.occurrences.map(\.selectedSection) == ["TT", nil, "SS", nil])
        #expect(graph.occurrences.map(\.parentOccurrenceID) == [nil, 0, nil, 2])
    }
    @Test func externalLibraryGraphKeepsActualSelectedSection() async throws {
        let fixture = try SpiceCandidateFixture.make(files: [
            "root": "* root\n.lib child.sp FF\n",
            "child": "* child\n.lib TT\n.include absent.sp\n.endl TT\n.lib FF\n.model c D\n.endl FF\n"])
        defer { fixture.remove() }
        let graph = try await fixture.discover()
        #expect(graph.dependencies.count == 1)
        #expect(graph.dependencies[0].directiveKind == "externalLibrary")
        #expect(graph.dependencies[0].selectedSection == "ff")
        #expect(graph.occurrences[1].selectedSection == "ff")
    }
    @Test func approvedSearchAndPhysicalAliasRoutesAreRetained() async throws {
        let fixture = try SpiceCandidateFixture.make(files: ["root": "* root\n.include child.sp\n", "child": "* child\n.model c D\n"], searches: ["models"])
        defer { fixture.remove() }
        let binding = try #require(fixture.request.sources.first { $0.sourceKey == "child" })
        let models = PDKSpiceCandidateBinding(sourceKey: binding.sourceKey, assetID: binding.assetID,
            logicalRoutes: ["models/child.sp"], rootID: binding.rootID, relativePath: binding.relativePath,
            budget: binding.budget, descriptor: binding.descriptor)
        let alias = PDKSpiceCandidateBinding(sourceKey: binding.sourceKey, assetID: binding.assetID,
            logicalRoutes: ["alias/child.sp"], rootID: binding.rootID, relativePath: binding.relativePath,
            budget: binding.budget, descriptor: binding.descriptor)
        let root = try #require(fixture.request.sources.first { $0.sourceKey == "root" })
        let graph = try await fixture.discover(fixture.changing(sources: [root, models, alias]))
        #expect(graph.occurrences[1].logicalRoute == "models/child.sp")
        #expect(graph.sources[1].source.logicalRoutes == ["models/child.sp", "alias/child.sp"])
    }
    @Test(arguments: ["absent.sp", "../outside.sp", "/absolute.sp"])
    func unknownAndEscapingRoutesRefuse(literal: String) async throws {
        let fixture = try SpiceCandidateFixture.make(files: ["root": "* root\n.include \"" + literal + "\"\n"])
        defer { fixture.remove() }
        let expected: PDKSpiceCandidateDiscoveryError = literal == "absent.sp" ? .missingRoute : .escapingRoute
        await #expect(throws: expected) { try await fixture.discover() }
    }
    @Test func ambiguousAndConflictingBindingsRefuseBeforeReading() async throws {
        let fixture = try SpiceCandidateFixture.make(files: ["root": "* root\n.model m D\n", "child": "* child\n.model c D\n"])
        defer { fixture.remove() }
        let root = try #require(fixture.request.sources.first { $0.sourceKey == "root" })
        let child = try #require(fixture.request.sources.first { $0.sourceKey == "child" })
        let ambiguous = PDKSpiceCandidateBinding(sourceKey: child.sourceKey, assetID: nil,
            logicalRoutes: root.logicalRoutes, rootID: child.rootID, relativePath: child.relativePath,
            budget: child.budget, descriptor: child.descriptor)
        await #expect(throws: PDKSpiceCandidateDiscoveryError.ambiguousRoute) {
            try await fixture.discover(fixture.changing(sources: [root, ambiguous]))
        }
        let conflicting = PDKSpiceCandidateBinding(sourceKey: root.sourceKey, assetID: root.assetID,
            logicalRoutes: ["alias.sp"], rootID: child.rootID, relativePath: child.relativePath,
            budget: child.budget, descriptor: child.descriptor)
        await #expect(throws: PDKSpiceCandidateDiscoveryError.invalidRequest) {
            try await fixture.discover(fixture.changing(sources: [root, conflicting]))
        }
    }
    @Test func actualContextualCycleRefuses() async throws {
        let fixture = try SpiceCandidateFixture.make(files: ["root": "* root\n.include child.sp\n", "child": "* child\n.include root.sp\n"])
        defer { fixture.remove() }
        await #expect(throws: PDKSpiceCandidateDiscoveryError.contextualCycle) { try await fixture.discover() }
    }
    @Test func unknownConditionalMeaningCannotPublishDraftGraph() async throws {
        let fixture = try SpiceCandidateFixture.make(files: ["root": "* root\n.if (missing_parameter)\n.include child.sp\n.endif\n",
            "child": "* child\n.model c D\n"])
        defer { fixture.remove() }
        do { _ = try await fixture.discover(); Issue.record("Unresolved candidate graph returned") }
        catch let error as PDKSpiceCandidateDiscoveryError {
            if case .syntax = error {} else if case .unsupportedSemantics = error {}
            else { Issue.record("Unresolved condition cause lost") }
        }
    }
    @Test func syntaxFailureRetainsObservedPhysicalOrigin() async throws {
        let fixture = try SpiceCandidateFixture.make(files: ["root": "* root\n.model broken\n"])
        defer { fixture.remove() }
        do { _ = try await fixture.discover(); Issue.record("Malformed candidate returned") }
        catch let error as PDKSpiceCandidateDiscoveryError {
            guard case .syntax(let diagnostic) = error else { Issue.record("Syntax cause lost"); return }
            #expect(diagnostic.sourceKey == "root")
            #expect(diagnostic.line == 2)
        }
    }
    @Test func quotaAndCancellationUseSharedInvocationOwner() async throws {
        let fixture = try SpiceCandidateFixture.make(files: ["root": "* root\n.model m D\n"])
        defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget(overrides: [.uniqueSources: 1]))
        defer { resources.close() }
        _ = try await fixture.discover(resources: resources)
        do { _ = try await fixture.discover(resources: resources); Issue.record("Shared cumulative limit reset") }
        catch let error as PDKSpiceCandidateDiscoveryError {
            if case .resource(.exhausted(let dimension, _, _)) = error { #expect(dimension == .uniqueSources) }
            else { Issue.record("Quota cause lost") }
        }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await fixture.discover()
        }
        await #expect(throws: PDKSpiceCandidateDiscoveryError.resource(.cancelled)) { try await task.value }
    }
    @Test func finalGraphCopyOwnsOutputAndCaptureLifetime() async throws {
        let fixture = try SpiceCandidateFixture.make(files: ["root": "* root\n.include child.sp\n", "child": "* child\n.model c D\n"])
        defer { fixture.remove() }
        let resources = LocalPDKAdmissionResources(budget: try SpiceProfileFixture.budget()); defer { resources.close() }
        var graph: PDKSpiceCandidateGraph? = try await fixture.discover(resources: resources)
        var retained = graph
        graph = nil
        #expect(retained?.dependencies[0].literalRoute == "child.sp")
        #expect(retained?.sources[1].capture.byteCount == UInt64("* child\n.model c D\n".utf8.count))
        let live = try #require(resources.snapshot().dimensions.first { $0.dimension == .liveOwnedBytes })
        if case .live(let current, _) = live.usage { #expect(current > 0) }
        else { Issue.record("Live capacity observation lost") }
        retained = nil
        let final = try #require(resources.snapshot().dimensions.first { $0.dimension == .liveOwnedBytes })
        if case .live(let current, _) = final.usage { #expect(current == 0) }
        else { Issue.record("Live capacity observation lost") }
        let scratch = try #require(resources.snapshot().dimensions.first { $0.dimension == .temporaryBytes })
        if case .live(let current, _) = scratch.usage { #expect(current == 0) }
        else { Issue.record("Temporary capacity observation lost") }
    }
}
