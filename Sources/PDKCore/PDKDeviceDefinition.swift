import Foundation

public struct PDKDeviceDefinition: Sendable, Hashable, Codable {
    public var deviceID: String
    public var modelName: String
    public var terminals: [PDKDeviceTerminal]
    public var extractionRecognition: PDKExtractionRecognition?
    public var parameterNames: [String]
    public var aliases: [String]

    public init(
        deviceID: String,
        modelName: String,
        terminals: [PDKDeviceTerminal],
        extractionRecognition: PDKExtractionRecognition? = nil,
        parameterNames: [String] = [],
        aliases: [String] = []
    ) {
        self.deviceID = deviceID
        self.modelName = modelName
        self.terminals = terminals
        self.extractionRecognition = extractionRecognition
        self.parameterNames = parameterNames
        self.aliases = aliases
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID) ?? ""
        modelName = try container.decodeIfPresent(String.self, forKey: .modelName) ?? ""
        terminals = try container.decodeIfPresent([PDKDeviceTerminal].self, forKey: .terminals) ?? []
        extractionRecognition = try container.decodeIfPresent(
            PDKExtractionRecognition.self,
            forKey: .extractionRecognition
        )
        parameterNames = try container.decodeIfPresent([String].self, forKey: .parameterNames) ?? []
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case deviceID
        case modelName
        case terminals
        case extractionRecognition
        case parameterNames
        case aliases
    }
}
