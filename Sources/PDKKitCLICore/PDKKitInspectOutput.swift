import Foundation
import PDKCore

public struct PDKKitInspectOutput: Sendable, Hashable, Codable {
    public var command: String
    public var manifestPath: String
    public var schemaVersion: Int
    public var digest: String
    public var manifest: PDKManifest

    public init(
        command: String,
        manifestPath: String,
        schemaVersion: Int,
        digest: String,
        manifest: PDKManifest
    ) {
        self.command = command
        self.manifestPath = manifestPath
        self.schemaVersion = schemaVersion
        self.digest = digest
        self.manifest = manifest
    }
}
