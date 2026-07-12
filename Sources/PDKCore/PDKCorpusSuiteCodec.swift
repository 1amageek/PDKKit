import Foundation

public struct PDKCorpusSuiteCodec: Sendable {
    public init() {}

    public func decode(data: Data) throws -> PDKCorpusSuite {
        let suite: PDKCorpusSuite
        do {
            suite = try JSONDecoder().decode(PDKCorpusSuite.self, from: data)
        } catch {
            throw PDKCorpusSuiteCodecError.invalidJSON(String(describing: error))
        }
        guard suite.schemaVersion <= PDKCorpusSuite.currentSchemaVersion else {
            throw PDKCorpusSuiteCodecError.unsupportedSchemaVersion(suite.schemaVersion)
        }
        return suite
    }

    public func decode(contentsOf url: URL) throws -> PDKCorpusSuite {
        let data = try Data(contentsOf: url)
        return try decode(data: data)
    }

    public func encode(_ suite: PDKCorpusSuite, pretty: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(suite)
    }
}
