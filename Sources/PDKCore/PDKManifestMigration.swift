import Foundation

public struct PDKManifestMigrationResult: Sendable, Hashable, Codable {
    public var sourceSchemaVersion: Int
    public var targetSchemaVersion: Int
    public var wasMigrated: Bool
    public var manifest: PDKManifest

    public init(
        sourceSchemaVersion: Int,
        targetSchemaVersion: Int,
        wasMigrated: Bool,
        manifest: PDKManifest
    ) {
        self.sourceSchemaVersion = sourceSchemaVersion
        self.targetSchemaVersion = targetSchemaVersion
        self.wasMigrated = wasMigrated
        self.manifest = manifest
    }
}
