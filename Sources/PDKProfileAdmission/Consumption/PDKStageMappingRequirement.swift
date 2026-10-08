import PDKCore

public struct PDKStageMappingRequirement: Sendable {
    public enum Condition: Sendable {
        case factKind(String), name(String)
        case layer(PDKLayerDefinition), device(PDKDeviceDefinition)
    }
    public let rootOccurrenceID: UInt64
    public let condition: Condition
    public let candidates: PDKAdmissionCollection<PDKConsumedMapping>
    internal init(rootOccurrenceID: UInt64, condition: Condition, candidates: PDKAdmissionCollection<PDKConsumedMapping>) {
        self.rootOccurrenceID = rootOccurrenceID; self.condition = condition; self.candidates = candidates
    }
    internal static func accepts(_ mapping: PDKProfileMappingFact, condition: Condition, work: PDKConsumptionWork)
        throws(PDKProfileConsumptionError) -> Bool {
        switch condition {
        case .factKind(let kind): return try work.equal(mapping.factKind, kind)
        case .name(let name): return try work.equal(mapping.name, name)
        case .layer(let layer):
            try work.step()
            guard mapping.layerNumber == layer.number, mapping.layerPurpose == layer.purpose else { return false }
            return try work.equal(mapping.name, layer.name)
        case .device(let device):
            guard try work.equal(mapping.name, device.modelName), mapping.terminals.count == device.terminals.count else { return false }
            for index in mapping.terminals.indices {
                try work.step(); guard device.terminals[index].order == index,
                    try work.equal(mapping.terminals[index], device.terminals[index].name) else { return false }
            }; return true
        }
    }
}
