import Foundation

public struct PDKCorpusSuite: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var suiteID: String
    public var processID: String
    public var version: String
    public var cases: [PDKCorpusCase]
    public var metadata: [String: String]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        suiteID: String,
        processID: String,
        version: String,
        cases: [PDKCorpusCase],
        metadata: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.suiteID = suiteID
        self.processID = processID
        self.version = version
        self.cases = cases.sorted { $0.caseID < $1.caseID }
        self.metadata = metadata
    }
}
