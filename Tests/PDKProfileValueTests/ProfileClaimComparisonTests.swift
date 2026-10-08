import Synchronization
import Testing
import CircuiteFoundation
@testable import PDKCore

@Suite struct ProfileClaimComparisonTests {
    @Test func cooperativeEqualityMatchesEveryCheckedVariant() throws {
        let fixture = ProfileValueTests()
        let original = try fixture.fixture(dependencies: true)
        let base = try fixture.claim(original)
        var variants = [base, try fixture.claim(fixture.fixture(temperature: 26)),
            try fixture.claim(fixture.fixture(shared: true)),
            try fixture.claim(fixture.fixture(shared: true, multiple: true))]
        let d = original.0, r = d.requirements[0]
        for variant in ["profile", "process", "version", "search", "policy", "environment", "purpose", "section", "facts", "sourceRoute", "edge"] {
            let requirement = try PDKViewRequirement(requirementID: r.requirementID,
                purposeID: variant == "purpose" ? "other-purpose" : r.purposeID, view: r.view, role: r.role,
                assetIDs: r.assetIDs, cornerIDs: r.cornerIDs,
                selectedSection: variant == "section" ? "tt" : r.selectedSection,
                isShared: r.isShared, allowsMultipleSources: r.allowsMultipleSources,
                demandedFactKinds: variant == "facts" ? ["dependencies", "devices"] : r.demandedFactKinds)
            let source = d.sources[0]
            let changedSource = try PDKProfileSource(sourceKey: source.sourceKey, assetID: source.assetID,
                reference: source.reference, logicalRoutes: variant == "sourceRoute" ? ["relocated.sp"] : source.logicalRoutes)
            let edge = d.dependencies[0]
            let changedEdge = try PDKSourceDependency(parentSourceKey: edge.parentSourceKey,
                parentReference: edge.parentReference, statementByteOffset: variant == "edge" ? 3 : edge.statementByteOffset,
                statementOrdinal: edge.statementOrdinal, directiveKind: edge.directiveKind,
                literalRoute: edge.literalRoute, childSourceKey: edge.childSourceKey, childReference: edge.childReference,
                selectedSection: edge.selectedSection, preprocessingIdentity: edge.preprocessingIdentity,
                lexicalOrder: edge.lexicalOrder)
            let definition = try PDKProfileDefinition(profileID: variant == "profile" ? "other-profile" : d.profileID,
                manifestReference: d.manifestReference, processID: variant == "process" ? "other-process" : d.processID,
                version: variant == "version" ? "2" : d.version, requiredCornerIDs: d.requiredCornerIDs,
                requirements: [requirement], sources: [changedSource, d.sources[1]],
                orderedSearchRoutes: variant == "search" ? ["alternate"] : d.orderedSearchRoutes,
                dependencies: [changedEdge], inspectionPolicyIdentity: variant == "policy" ? "other-policy" : d.inspectionPolicyIdentity,
                initialPreprocessingIdentity: variant == "environment" ? "other-environment" : d.initialPreprocessingIdentity)
            var manifest = original.1
            manifest.processID = definition.processID; manifest.version = definition.version
            variants.append(try fixture.claim((definition, manifest, original.2)))
        }
        var pvtVariant = original.1
        pvtVariant.corners[0].pvt.voltage = 1.2
        pvtVariant.corners[0].pvt.process.name = "slow"
        pvtVariant.corners[0].pvt.process.nominal = false
        variants.append(try fixture.claim((d, pvtVariant, original.2)))
        variants.append(try fixture.claim((d, original.1, fixture.reference("e", kind: "pdk.profile", format: .json))))
        // Definition order is part of ordinary equality even when canonical selection bytes agree.
        let reordered = try fixture.claim((fixture.replacing(d, sources: d.sources.reversed()), original.1, original.2))
        variants.append(reordered)
        #expect(reordered.semanticSelectionDigest == base.semanticSelectionDigest)
        #expect(try !base.matchesExactly(reordered, resources: ProfileTestAccounting()))
        for lhs in variants {
            for rhs in variants {
                #expect(try lhs.matchesExactly(rhs, resources: ProfileTestAccounting()) == (lhs == rhs))
            }
        }
        var unicodeA = original.1, unicodeB = original.1
        unicodeA.corners[0].pvt.process.name = "é"
        unicodeB.corners[0].pvt.process.name = "e\u{301}"
        let a = try fixture.claim((d, unicodeA, original.2)), b = try fixture.claim((d, unicodeB, original.2))
        #expect(try a.matchesExactly(b, resources: ProfileTestAccounting()) == (a == b))
    }

    @Test func cumulativeWorkQuotaRefusesRepeatedComparison() throws {
        let value = try ProfileValueTests().claim(ProfileValueTests().fixture(dependencies: true))
        let probe = ProfileTestAccounting()
        #expect(try value.matchesExactly(value, resources: probe))
        let cost = probe.used(.parserWork)
        #expect(cost > 0)
        let limited = ProfileTestAccounting()
        limited.limit(.parserWork, to: cost * 2 - 1)
        #expect(try value.matchesExactly(value, resources: limited))
        do throws(PDKProfileValueError) {
            _ = try value.matchesExactly(value, resources: limited)
            Issue.record("Expected cumulative work exhaustion")
        } catch {
            guard case .resource(.exhausted(dimension: .parserWork, limit: _, attempted: _)) = error else {
                Issue.record("Unexpected comparison error: \(error)"); return
            }
        }
        #expect(limited.used(.parserWork) <= cost * 2 - 1)
    }

    @Test func terminalFailuresIncludeFinalBooleanPublication() throws {
        let fixture = ProfileValueTests()
        let value = try fixture.claim(fixture.fixture())
        let different = try fixture.claim(fixture.fixture(temperature: 26))
        for other in [value, different] {
            let probe = ClaimComparisonCheckAccounting()
            #expect(try value.matchesExactly(other, resources: probe) == (value == other))
            for failure in [PDKAdmissionResourceError.cancelled, .deadlineExceeded] {
                for boundary in [1, 5, probe.checkCount] {
                    let refusing = ClaimComparisonCheckAccounting(failAtCheck: boundary, failure: failure)
                    #expect(throws: PDKProfileValueError.resource(failure)) {
                        try value.matchesExactly(other, resources: refusing)
                    }
                }
            }
        }
    }

    @Test func comparisonBorrowsExistingBackingWithoutPayloadReservations() throws {
        let value = try ProfileValueTests().claim(ProfileValueTests().fixture(dependencies: true))
        let accounting = ProfileTestAccounting()
        accounting.limit(.liveOwnedBytes, to: 0); accounting.limit(.temporaryBytes, to: 0)
        accounting.limit(.hashedBytes, to: 0)
        try value.sourceClosure.withUnsafeBufferPointer { original throws -> Void in
            let matches = try value.matchesExactly(value, resources: accounting)
            #expect(matches)
            value.sourceClosure.withUnsafeBufferPointer { after in
                #expect(original.baseAddress == after.baseAddress)
            }
        }
        #expect(accounting.peak(.liveOwnedBytes) == 0)
        #expect(accounting.peak(.temporaryBytes) == 0)
        #expect(accounting.used(.hashedBytes) == 0)
    }
}

private final class ClaimComparisonCheckAccounting: PDKAdmissionResourceAccounting {
    private struct State { var checks = 0 }
    private let state = Mutex(State())
    private let work = ProfileTestAccounting()
    private let failAtCheck: Int?
    private let failure: PDKAdmissionResourceError
    init(failAtCheck: Int? = nil, failure: PDKAdmissionResourceError = .cancelled) {
        self.failAtCheck = failAtCheck; self.failure = failure
    }
    var checkCount: Int { state.withLock { $0.checks } }
    func check() throws(PDKAdmissionResourceError) {
        let index = state.withLock { $0.checks += 1; return $0.checks }
        if index == failAtCheck { throw failure }
    }
    func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
        try work.reserve(cost)
    }
}
