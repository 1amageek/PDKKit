import Foundation
import PDKCore

public struct PDKKitInspectOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var sourceSchemaVersion: Int
    public var targetSchemaVersion: Int
    public var wasMigrated: Bool
    public var digest: String
    public var manifest: PDKManifest

    public init(
        command: String,
        manifestPath: String,
        sourceSchemaVersion: Int,
        targetSchemaVersion: Int,
        wasMigrated: Bool,
        digest: String,
        manifest: PDKManifest
    ) {
        self.command = command
        self.manifestPath = manifestPath
        self.sourceSchemaVersion = sourceSchemaVersion
        self.targetSchemaVersion = targetSchemaVersion
        self.wasMigrated = wasMigrated
        self.digest = digest
        self.manifest = manifest
    }
}
