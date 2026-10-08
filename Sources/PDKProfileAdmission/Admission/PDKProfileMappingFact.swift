import PDKCore

/// Format-normalized observation with its actual exact source origin.
public struct PDKProfileMappingFact: Sendable {
    public let input: PDKProfileSourceInput
    public let factKind: String
    public let name: String
    public let terminals: [String]
    public let model: PDKProfileModelDetail?
    public let origin: PDKProfilePhysicalOrigin?
    public let layerNumber: Int?
    public let layerPurpose: PDKLayerPurpose?
    public init(input: PDKProfileSourceInput, factKind: String, name: String,
                terminals: [String] = [], layerNumber: Int? = nil, layerPurpose: PDKLayerPurpose? = nil,
                model: PDKProfileModelDetail? = nil, origin: PDKProfilePhysicalOrigin? = nil) {
        self.model = model; self.origin = origin
        self.input = input; self.factKind = factKind; self.name = name; self.terminals = terminals
        self.layerNumber = layerNumber; self.layerPurpose = layerPurpose
    }
}
