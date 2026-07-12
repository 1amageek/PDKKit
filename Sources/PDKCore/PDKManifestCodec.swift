import Foundation

public enum PDKManifestCodec {
    public static func decode(data: Data) throws -> PDKManifestMigrationResult {
        let sourceSchemaVersion = try sourceVersion(data: data)
        let manifest: PDKManifest
        do {
            manifest = try JSONDecoder().decode(PDKManifest.self, from: data)
        } catch let error as PDKManifestError {
            throw error
        } catch {
            throw PDKManifestError.invalidField(field: "json", reason: String(reflecting: error))
        }
        return PDKManifestMigrationResult(
            sourceSchemaVersion: sourceSchemaVersion,
            targetSchemaVersion: PDKManifest.currentSchemaVersion,
            wasMigrated: sourceSchemaVersion != PDKManifest.currentSchemaVersion,
            manifest: manifest
        )
    }

    public static func decode(contentsOf url: URL) throws -> PDKManifestMigrationResult {
        let data = try Data(contentsOf: url)
        return try decode(data: data)
    }

    public static func encode(_ manifest: PDKManifest, pretty: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if pretty {
            formatting.insert(.prettyPrinted)
        }
        encoder.outputFormatting = formatting
        return try encoder.encode(manifest)
    }

    private static func sourceVersion(data: Data) throws -> Int {
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw PDKManifestError.invalidField(field: "json", reason: "root must be an object")
            }
            guard let value = dictionary["schemaVersion"] else { return 0 }
            guard let version = value as? Int else {
                throw PDKManifestError.invalidField(field: "schemaVersion", reason: "must be an integer")
            }
            guard version >= 0 else {
                throw PDKManifestError.invalidField(field: "schemaVersion", reason: "must not be negative")
            }
            return version
        } catch let error as PDKManifestError {
            throw error
        } catch {
            throw PDKManifestError.invalidField(field: "json", reason: String(reflecting: error))
        }
    }
}
