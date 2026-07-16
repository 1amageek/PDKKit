import Foundation

public enum PDKManifestCodec {
    public static func decode(data: Data) throws -> PDKManifest {
        do {
            return try JSONDecoder().decode(PDKManifest.self, from: data)
        } catch let error as PDKManifestError {
            throw error
        } catch {
            throw PDKManifestError.invalidField(field: "json", reason: String(reflecting: error))
        }
    }

    public static func decode(contentsOf url: URL) throws -> PDKManifest {
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

}
