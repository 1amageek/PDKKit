import PDKCore

/// Format-normalized observation with its actual exact source origin.
public struct PDKProfileMappingFact: Sendable {
    public let input: PDKProfileSourceInput
    public let factKind: String
    public let name: String
    public let terminals: [String]
    public let layerNumber: Int?
    public let layerPurpose: PDKLayerPurpose?
    public init(input: PDKProfileSourceInput, factKind: String, name: String,
                terminals: [String] = [], layerNumber: Int? = nil, layerPurpose: PDKLayerPurpose? = nil) {
        self.input = input; self.factKind = factKind; self.name = name; self.terminals = terminals
        self.layerNumber = layerNumber; self.layerPurpose = layerPurpose
    }
}
