import Foundation
import PDKCore
import PDKDiscovery
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ControlledDecodingContextTests {
    private static let contextKey: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "PDKKit.tests.caller-context") else {
            preconditionFailure("The fixed nonempty context key must be valid.")
        }
        return key
    }()

    private final class Context: Sendable {
        let visits = Mutex(0)
        let rejectValue: Bool
        init(rejectValue: Bool = false) { self.rejectValue = rejectValue }
    }

    private struct ContextValue: Decodable, Sendable {
        let value: String
        init(from decoder: any Decoder) throws {
            guard let context = decoder.userInfo[ControlledDecodingContextTests.contextKey] as? Context,
                  let accounting = decoder.userInfo[PDKAdmissionDecodingContext.accountingKey]
                    as? any PDKAdmissionResourceAccounting else {
                throw PDKBoundedDecodeError.unsupportedValue("Missing caller decoding context")
            }
            try accounting.charge(PDKAdmissionCost(dimension: .parserWork, amount: 1))
            context.visits.withLock { $0 += 1 }
            value = try decoder.singleValueContainer().decode(String.self)
            if context.rejectValue { throw PDKManifestError.invalidAssetPath(value) }
        }
    }

    private struct Nested: Decodable, Sendable {
        let values: [ContextValue]
    }

    private struct ContextWorkRefusal: PDKAdmissionResourceAccounting {
        let upstream: DecodeTestAccounting
        let failure: PDKAdmissionResourceError
        func charge(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) {
            if cost.dimension == .parserWork { throw failure }
            try upstream.charge(cost)
        }
        func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
            try upstream.reserve(cost)
        }
        func check() throws(PDKAdmissionResourceError) { try upstream.check() }
    }

    private final class PostChargeCancellation: PDKAdmissionResourceAccounting {
        let upstream: DecodeTestAccounting
        private let cancelled = Mutex(false)
        init(_ upstream: DecodeTestAccounting) { self.upstream = upstream }
        func charge(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) {
            try upstream.charge(cost)
            if cost.dimension == .parserWork { cancelled.withLock { $0 = true } }
        }
        func reserve(_ cost: PDKAdmissionCost) throws(PDKAdmissionResourceError) -> PDKAdmissionReservation {
            try upstream.reserve(cost)
        }
        func check() throws(PDKAdmissionResourceError) {
            if cancelled.withLock({ $0 }) { throw .cancelled }
            try upstream.check()
        }
    }

    private func load<Value: Decodable & Sendable>(_ type: Value.Type, _ bytes: [UInt8],
        _ accounting: any PDKAdmissionResourceAccounting, context: [CodingUserInfoKey: any Sendable],
        validate: (any Decoder) throws -> Void = { _ in }) throws(PDKControlledDecodeFailure)
        -> PDKDecodedDocument<Value> {
        try NativePDKBoundedDocumentDecoder().decodeAudited(type, bytes: bytes.span,
            accounting: accounting, rejectUnknownFields: true, additionalUserInfo: context, validate: validate)
    }

    @Test func contextReachesValidationAndKeyedUnkeyedChildrenWithTheInvocationAccountant() throws {
        let bytes = Array(#"{"values":["first","second"]}"#.utf8)
        let context = Context()
        let accounting = DecodeTestAccounting()
        var validated = false
        var first: PDKDecodedDocument<Nested>? = try load(Nested.self, bytes, accounting,
            context: [Self.contextKey: context]) { decoder in
            #expect(decoder.userInfo[Self.contextKey] as? Context === context)
            let resources = try #require(decoder.userInfo[PDKAdmissionDecodingContext.accountingKey]
                as? any PDKAdmissionResourceAccounting)
            let before = accounting.amount(.parserWork)
            try resources.charge(PDKAdmissionCost(dimension: .parserWork, amount: 7))
            #expect(accounting.amount(.parserWork) == before + 7)
            validated = true
        }
        #expect(validated)
        #expect(context.visits.withLock { $0 } == 2)
        #expect(first?.value.values.map(\.value) == ["first", "second"])
        #expect(first?.sourceReference == nil)
        var copy = first
        first = nil
        #expect(copy?.value.values.count == 2)
        #expect(accounting.amount(.liveOwnedBytes) > 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
        copy = nil
        #expect(accounting.amount(.liveOwnedBytes) == 0)
    }

    @Test func originalOverloadRetainsItsEmptyContextBehavior() throws {
        let bytes = Array(#""ordinary""#.utf8)
        let accounting = DecodeTestAccounting()
        let decoded = try NativePDKBoundedDocumentDecoder().decodeAudited(String.self, bytes: bytes.span,
            accounting: accounting, rejectUnknownFields: true, validate: { _ in })
        #expect(decoded.value == "ordinary")
        do {
            _ = try NativePDKBoundedDocumentDecoder().decodeAudited(ContextValue.self, bytes: bytes.span,
                accounting: accounting, rejectUnknownFields: true, validate: { _ in })
            Issue.record("The original overload unexpectedly supplied caller context")
        } catch {
            #expect(error.cause == .unsupportedValue("Missing caller decoding context"))
        }
    }

    @Test(arguments: ["PDKKit.admission.resources", "PDKKit.admission.controlled-manifest"])
    func reservedContextFailsBeforeParsingOrValidation(rawKey: String) throws {
        let key = try #require(CodingUserInfoKey(rawValue: rawKey))
        let bytes = Array(#""unused""#.utf8)
        let accounting = DecodeTestAccounting()
        var validated = false
        do {
            _ = try load(String.self, bytes, accounting, context: [key: "replacement"]) { _ in validated = true }
            Issue.record("A reserved PDK context was replaced")
        } catch {
            #expect(error.cause == .unsupportedValue("Reserved PDK decoding context"))
        }
        #expect(!validated)
        #expect(accounting.amount(.decodedElements) == 0)
        #expect(accounting.amount(.liveOwnedBytes) == 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
    }

    @Test func mergedDictionaryCapacityIsAdmittedBeforeValidation() throws {
        let bytes = Array(#""small""#.utf8)
        let baseline = DecodeTestAccounting()
        _ = try load(String.self, bytes, baseline, context: [:])
        let limit = baseline.state.withLock { $0.peak[.temporaryBytes, default: 0] }
        let accounting = DecodeTestAccounting(limits: [.temporaryBytes: limit])
        var context: [CodingUserInfoKey: any Sendable] = [:]
        for index in 0..<256 {
            let key = try #require(CodingUserInfoKey(rawValue: "PDKKit.tests.context-\(index)"))
            context[key] = index
        }
        var validated = false
        do {
            _ = try load(String.self, bytes, accounting, context: context) { _ in validated = true }
            Issue.record("Merged context dictionary exceeded its invocation capacity")
        } catch {
            guard case .resource(.exhausted(let dimension, let observedLimit, let attempted)) = error.cause else {
                Issue.record("Unexpected capacity failure: \(error.cause)"); return
            }
            #expect(dimension == .temporaryBytes)
            #expect(observedLimit == limit)
            #expect(attempted > limit)
        }
        #expect(!validated)
        #expect(accounting.amount(.liveOwnedBytes) == 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
    }

    @Test func originalDecodedFailureCauseAndCopiedOwnerSurviveContextForwarding() throws {
        let path = String(repeating: "invalid/caller/path/", count: 128)
        let bytes = Array(try JSONEncoder().encode(path))
        let accounting = DecodeTestAccounting()
        let context = Context(rejectValue: true)
        var first: PDKControlledDecodeFailure?
        do {
            _ = try load(ContextValue.self, bytes, accounting, context: [Self.contextKey: context])
            Issue.record("Custom checked constructor failure was accepted")
        } catch { first = error }
        var copy = first
        first = nil
        #expect(copy?.cause == .manifest(.invalidAssetPath(path)))
        #expect(context.visits.withLock { $0 } == 1)
        #expect(accounting.amount(.liveOwnedBytes) >= UInt64(path.utf8.count))
        #expect(accounting.amount(.temporaryBytes) == 0)
        copy = nil
        #expect(accounting.amount(.liveOwnedBytes) == 0)
    }

    @Test(arguments: [PDKAdmissionResourceError.cancelled,
        .unsupportedBudgetCapability("caller-owned context-work cause")])
    func refusalDuringContextWorkKeepsTheOriginalCauseAndRefundsOwnership(original: PDKAdmissionResourceError) throws {
        let bytes = Array(#""unused""#.utf8)
        let context = Context()
        let accounting = DecodeTestAccounting()
        let refusal = ContextWorkRefusal(upstream: accounting, failure: original)
        var validated = false
        do {
            _ = try load(ContextValue.self, bytes, refusal, context: [Self.contextKey: context]) { _ in validated = true }
            Issue.record("Context-work cancellation published a decoded result")
        } catch {
            #expect(error.cause == .resource(original))
        }
        #expect(!validated)
        #expect(context.visits.withLock { $0 } == 0)
        #expect(accounting.amount(.decodedElements) == 0)
        #expect(accounting.amount(.liveOwnedBytes) == 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
    }

    @Test func normalChargeReturnCannotHideCancellationBehindReservedKeyRefusal() throws {
        let bytes = Array(#""unused""#.utf8)
        let accounting = DecodeTestAccounting()
        let cancellation = PostChargeCancellation(accounting)
        var validated = false
        do {
            _ = try load(String.self, bytes, cancellation,
                context: [PDKAdmissionDecodingContext.accountingKey: "replacement"]) { _ in validated = true }
            Issue.record("Cancellation set by a completed charge published a decoded result")
        } catch {
            #expect(error.cause == .resource(.cancelled))
        }
        #expect(!validated)
        #expect(accounting.amount(.parserWork) > 0)
        #expect(accounting.amount(.decodedElements) == 0)
        #expect(accounting.amount(.liveOwnedBytes) == 0)
        #expect(accounting.amount(.temporaryBytes) == 0)
    }
}
