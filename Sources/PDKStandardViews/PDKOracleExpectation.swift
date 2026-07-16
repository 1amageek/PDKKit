import Foundation

public struct PDKOracleExpectation: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var oracleID: String
    public var processID: String
    public var version: String
    public var pdkDigest: String
    public var views: [PDKOracleViewExpectation]
    public var metadata: [String: String]

    public init(
        oracleID: String,
        processID: String,
        version: String,
        pdkDigest: String,
        views: [PDKOracleViewExpectation],
        metadata: [String: String] = [:]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.oracleID = oracleID
        self.processID = processID
        self.version = version
        self.pdkDigest = pdkDigest.lowercased()
        self.views = views.sorted {
            ($0.assetID, $0.format.rawValue) < ($1.assetID, $1.format.rawValue)
        }
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw PDKOracleExpectationError.unsupportedSchemaVersion(schemaVersion)
        }
        self.init(
            oracleID: try container.decode(String.self, forKey: .oracleID),
            processID: try container.decode(String.self, forKey: .processID),
            version: try container.decode(String.self, forKey: .version),
            pdkDigest: try container.decode(String.self, forKey: .pdkDigest),
            views: try container.decode([PDKOracleViewExpectation].self, forKey: .views),
            metadata: try container.decode([String: String].self, forKey: .metadata)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case oracleID
        case processID
        case version
        case pdkDigest
        case views
        case metadata
    }
}
