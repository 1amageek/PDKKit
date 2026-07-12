import Foundation

enum PDKKitCLIJSONCoding {
    static func decode<Model: Decodable>(_ type: Model.Type, atPath path: String) throws -> Model {
        let data: Data
        do {
            data = try Data(contentsOf: URL(filePath: path))
        } catch {
            throw PDKKitCLIError.unreadableFile(path: path, reason: error.localizedDescription)
        }
        do {
            return try JSONDecoder().decode(Model.self, from: data)
        } catch let error as DecodingError {
            throw PDKKitCLIError.invalidJSON(path: path, reason: describe(error))
        } catch {
            throw PDKKitCLIError.invalidJSON(path: path, reason: error.localizedDescription)
        }
    }

    static func encode<Model: Encodable>(_ value: Model, pretty: Bool) throws -> String {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if pretty { formatting.insert(.prettyPrinted) }
        encoder.outputFormatting = formatting
        do {
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        } catch {
            throw PDKKitCLIError.internalError("Failed to encode JSON: \(error.localizedDescription)")
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            "missing key '\(key.stringValue)' at \(path(context))"
        case .typeMismatch(_, let context):
            "type mismatch at \(path(context)): \(context.debugDescription)"
        case .valueNotFound(_, let context):
            "missing value at \(path(context)): \(context.debugDescription)"
        case .dataCorrupted(let context):
            "corrupted data at \(path(context)): \(context.debugDescription)"
        @unknown default:
            String(describing: error)
        }
    }

    private static func path(_ context: DecodingError.Context) -> String {
        let value = context.codingPath.map(\.stringValue).joined(separator: ".")
        return value.isEmpty ? "<root>" : value
    }
}
