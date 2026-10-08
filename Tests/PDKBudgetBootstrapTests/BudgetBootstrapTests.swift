import Foundation
import PDKCore
import PDKKitCLICore
import Testing

@Suite(.timeLimit(.minutes(1)))
struct BudgetBootstrapTests {
    @Test func actualCoreCodecWireAndUnsignedMaxima() throws {
        let limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64.max) })
        let expected = try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: .max)
        let bytes = Array(try JSONEncoder().encode(expected))
        #expect(bytes.count == 874)
        let decoding: any PDKBudgetBootstrapDecoding = NativePDKBudgetBootstrapDecoder()
        let result = try decoding.decode(bytes.span, policy: .standard)
        #expect(result.budget == expected)
        #expect(result.inputByteCount == UInt64(bytes.count))
        #expect(result.dimensionEntryCapacity == 21)
        #expect(result.scannedWorkUnitCount >= result.inputByteCount)
    }

    @Test func escapedVocabularyAndFiniteWhitespaceReachThePolicyBoundary() throws {
        let limits = Dictionary(uniqueKeysWithValues: PDKAdmissionResourceDimension.allCases.map { ($0, UInt64.max) })
        let budget = try PDKAdmissionBudget(limits: limits, maximumElapsedNanoseconds: .max)
        let wire = Array(try JSONEncoder().encode(budget))
        var escaped: [UInt8] = [], quoted = false
        for byte in wire {
            if byte == 34 { quoted.toggle(); escaped.append(byte) }
            else if quoted { escaped.append(contentsOf: String(format: "\\u%04x", Int(byte)).utf8) }
            else { escaped.append(byte) }
        }
        #expect(escaped.count == 2524)
        let allowance = 13_860
        var boundary = [UInt8](repeating: 32, count: allowance)
        boundary.append(contentsOf: escaped)
        #expect(boundary.count == Int(PDKBudgetBootstrapPolicy.standard.maximumByteCount))
        let result = try NativePDKBudgetBootstrapDecoder().decode(boundary.span, policy: .standard)
        #expect(result.budget == budget)
        #expect(result.scannedWorkUnitCount <= result.inputByteCount + 64 * (21 * 21 + 16))
        boundary.append(32)
        #expect(throws: PDKBudgetBootstrapError.oversizedInput) {
            try NativePDKBudgetBootstrapDecoder().decode(boundary.span, policy: .standard)
        }
    }

    @Test func reorderedFieldsAndDimensionsPreserveCheckedMeaning() throws {
        let entries = PDKAdmissionResourceDimension.allCases.reversed().map { "\"\($0.rawValue)\",1" }.joined(separator: ",")
        let bytes = Array("{\"limits\":[\(entries)],\"maximumElapsedNanoseconds\":9,\"accountingVersion\":1,\"schemaVersion\":1}".utf8)
        let result = try NativePDKBudgetBootstrapDecoder().decode(bytes.span, policy: .standard)
        #expect(result.budget.limits.count == 21)
        #expect(result.budget.limits.values.allSatisfy { $0 == 1 })
        #expect(result.budget.maximumElapsedNanoseconds == 9)
    }

    @Test func duplicateRootAndDimensionNeverUseLastValueWins() throws {
        let duplicateRoot = fixture(extraRoot: ",\"schemaVersion\":1")
        #expect(throws: PDKBudgetBootstrapError.duplicateField) {
            try NativePDKBudgetBootstrapDecoder().decode(duplicateRoot.span, policy: .standard)
        }
        let duplicateDimension = fixture(extraLimits: ",\"searchRoots\",2")
        #expect(throws: PDKBudgetBootstrapError.duplicateDimension) {
            try NativePDKBudgetBootstrapDecoder().decode(duplicateDimension.span, policy: .standard)
        }
    }

    @Test func unknownKeysMissingLimitsAndObjectShapeRefuse() throws {
        let unknownRoot = fixture(extraRoot: ",\"unknown\":1")
        #expect(throws: PDKBudgetBootstrapError.unknownField) {
            try NativePDKBudgetBootstrapDecoder().decode(unknownRoot.span, policy: .standard)
        }
        let unknownDimension = fixture(extraLimits: ",\"unknown\",1")
        #expect(throws: PDKBudgetBootstrapError.unknownDimension) {
            try NativePDKBudgetBootstrapDecoder().decode(unknownDimension.span, policy: .standard)
        }
        let missing = fixture(limits: "\"searchRoots\",1")
        #expect(throws: PDKBudgetBootstrapError.incompleteLimits) {
            try NativePDKBudgetBootstrapDecoder().decode(missing.span, policy: .standard)
        }
        for payload in ["{}", "{\"limits\":{}}", "{\"limits\":[\"searchRoots\"]}",
                        "{\"schemaVersion\":2}", "{\"schemaVersion\":1,}", "{\"\\u00ff\":1}"] {
            let bytes = Array(payload.utf8)
            #expect(throws: PDKBudgetBootstrapError.self) {
                try NativePDKBudgetBootstrapDecoder().decode(bytes.span, policy: .standard)
            }
        }
    }

    @Test(arguments: ["0", "-1", "1.5", "1e3", "01", "18446744073709551616", "null", "true"])
    func invalidUnsignedAndNonpositiveBudgetRefuse(_ number: String) {
        let bytes = fixture(elapsed: number)
        #expect(throws: PDKBudgetBootstrapError.self) {
            try NativePDKBudgetBootstrapDecoder().decode(bytes.span, policy: .standard)
        }
    }

    @Test func malformedUtf8TrailingPayloadAndPolicyRefuse() throws {
        #expect(throws: PDKBudgetBootstrapError.invalidPolicy) { try PDKBudgetBootstrapPolicy(maximumByteCount: 0) }
        #expect(throws: PDKBudgetBootstrapError.invalidPolicy) { try PDKBudgetBootstrapPolicy(maximumByteCount: .max) }
        let bytes = fixture()
        #expect(throws: PDKBudgetBootstrapError.oversizedInput) {
            try NativePDKBudgetBootstrapDecoder().decode(bytes.span, policy: PDKBudgetBootstrapPolicy(maximumByteCount: UInt64(bytes.count - 1)))
        }
        #expect(try NativePDKBudgetBootstrapDecoder().decode(bytes.span,
            policy: PDKBudgetBootstrapPolicy(maximumByteCount: UInt64(bytes.count))).budget.limits.count == 21)
        for malformed in [bytes + Array(" true".utf8), [123, 34, 255, 34, 58, 49, 125]] {
            #expect(throws: PDKBudgetBootstrapError.self) {
                try NativePDKBudgetBootstrapDecoder().decode(malformed.span, policy: .standard)
            }
        }
    }

    @Test func cancellationIsObservedBeforeBootstrapPublication() async {
        let bytes = fixture()
        let task = Task<Void, Never> {
            withUnsafeCurrentTask { $0?.cancel() }
            #expect(throws: PDKBudgetBootstrapError.cancelled) {
                try NativePDKBudgetBootstrapDecoder().decode(bytes.span, policy: .standard)
            }
        }
        await task.value
    }

    @Test func nonpositiveLimitsAndUnsupportedVersionsRefuse() {
        let zeros = PDKAdmissionResourceDimension.allCases.map { "\"\($0.rawValue)\",0" }.joined(separator: ",")
        let invalid = fixture(limits: zeros)
        #expect(throws: PDKBudgetBootstrapError.invalidBudget) {
            try NativePDKBudgetBootstrapDecoder().decode(invalid.span, policy: .standard)
        }
        let current = String(decoding: fixture(), as: UTF8.self)
        for field in ["schemaVersion", "accountingVersion"] {
            let bytes = Array(current.replacingOccurrences(of: "\"\(field)\":1", with: "\"\(field)\":2").utf8)
            #expect(throws: PDKBudgetBootstrapError.unsupportedVersion) {
                try NativePDKBudgetBootstrapDecoder().decode(bytes.span, policy: .standard)
            }
        }
    }

    private func fixture(limits: String? = nil, extraLimits: String = "", elapsed: String = "1", extraRoot: String = "") -> [UInt8] {
        let entries = limits ?? PDKAdmissionResourceDimension.allCases.map { "\"\($0.rawValue)\",1" }.joined(separator: ",")
        return Array("{\"schemaVersion\":1,\"accountingVersion\":1,\"limits\":[\(entries)\(extraLimits)],\"maximumElapsedNanoseconds\":\(elapsed)\(extraRoot)}".utf8)
    }
}
