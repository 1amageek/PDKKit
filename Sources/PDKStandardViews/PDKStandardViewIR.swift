import Foundation
import CircuiteFoundation

public struct PDKStandardViewIR: Sendable, Hashable, Codable {
    public var format: PDKStandardViewFormat
    public var source: ArtifactLocator
    public var sourceArtifact: ArtifactReference?
    public var libraryName: String
    public var layerNames: [String]
    public var physicalLayerNumbers: [Int]
    public var cellNames: [String]
    public var viaNames: [String]
    public var modelNames: [String]
    public var modelTypes: [String]
    public var modelParameterNames: [String]
    public var spiceModels: [PDKSpiceModel]
    public var spiceSubcircuits: [PDKSpiceSubcircuit]
    public var pinNames: [String]
    public var cornerNames: [String]
    public var timingArcCount: Int
    public var timingRelatedPinNames: [String]
    public var timingTableValueCount: Int
    public var libertyCells: [PDKLibertyCell]
    public var libertyTimingArcs: [PDKLibertyTimingArc]
    public var libertyTimingTables: [PDKLibertyTimingTable]
    public var unitDeclarations: [String: String]
    public var elementCount: Int
    public var metadata: [String: String]

    public init(
        format: PDKStandardViewFormat,
        source: ArtifactLocator,
        sourceArtifact: ArtifactReference? = nil,
        libraryName: String,
        layerNames: [String] = [],
        physicalLayerNumbers: [Int] = [],
        cellNames: [String] = [],
        viaNames: [String] = [],
        modelNames: [String] = [],
        modelTypes: [String] = [],
        modelParameterNames: [String] = [],
        spiceModels: [PDKSpiceModel] = [],
        spiceSubcircuits: [PDKSpiceSubcircuit] = [],
        pinNames: [String] = [],
        cornerNames: [String] = [],
        timingArcCount: Int = 0,
        timingRelatedPinNames: [String] = [],
        timingTableValueCount: Int = 0,
        libertyCells: [PDKLibertyCell] = [],
        libertyTimingArcs: [PDKLibertyTimingArc] = [],
        libertyTimingTables: [PDKLibertyTimingTable] = [],
        unitDeclarations: [String: String] = [:],
        elementCount: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.format = format
        self.source = source
        self.sourceArtifact = sourceArtifact
        self.libraryName = libraryName
        self.layerNames = Self.sortedUnique(layerNames)
        self.physicalLayerNumbers = Array(Set(physicalLayerNumbers)).sorted()
        self.cellNames = Self.sortedUnique(cellNames)
        self.viaNames = Self.sortedUnique(viaNames)
        self.modelNames = Self.sortedUnique(modelNames)
        self.modelTypes = Self.sortedUnique(modelTypes)
        self.modelParameterNames = Self.sortedUnique(modelParameterNames)
        self.spiceModels = spiceModels.sorted { $0.name < $1.name }
        self.spiceSubcircuits = spiceSubcircuits.sorted { $0.name < $1.name }
        self.pinNames = Self.sortedUnique(pinNames)
        self.cornerNames = Self.sortedUnique(cornerNames)
        self.timingArcCount = timingArcCount
        self.timingRelatedPinNames = Self.sortedUnique(timingRelatedPinNames)
        self.timingTableValueCount = timingTableValueCount
        self.libertyCells = libertyCells.sorted { $0.name < $1.name }
        self.libertyTimingArcs = libertyTimingArcs.sorted {
            ($0.cellName, $0.pinName, $0.relatedPinName ?? "") <
                ($1.cellName, $1.pinName, $1.relatedPinName ?? "")
        }
        self.libertyTimingTables = libertyTimingTables.sorted {
            ($0.cellName, $0.pinName, $0.kind) < ($1.cellName, $1.pinName, $1.kind)
        }
        self.unitDeclarations = unitDeclarations
        self.elementCount = elementCount
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            format: try container.decode(PDKStandardViewFormat.self, forKey: .format),
            source: try container.decode(ArtifactLocator.self, forKey: .source),
            sourceArtifact: try container.decodeIfPresent(ArtifactReference.self, forKey: .sourceArtifact),
            libraryName: try container.decode(String.self, forKey: .libraryName),
            layerNames: try container.decodeIfPresent([String].self, forKey: .layerNames) ?? [],
            physicalLayerNumbers: try container.decodeIfPresent([Int].self, forKey: .physicalLayerNumbers) ?? [],
            cellNames: try container.decodeIfPresent([String].self, forKey: .cellNames) ?? [],
            viaNames: try container.decodeIfPresent([String].self, forKey: .viaNames) ?? [],
            modelNames: try container.decodeIfPresent([String].self, forKey: .modelNames) ?? [],
            modelTypes: try container.decodeIfPresent([String].self, forKey: .modelTypes) ?? [],
            modelParameterNames: try container.decodeIfPresent([String].self, forKey: .modelParameterNames) ?? [],
            spiceModels: try container.decodeIfPresent([PDKSpiceModel].self, forKey: .spiceModels) ?? [],
            spiceSubcircuits: try container.decodeIfPresent([PDKSpiceSubcircuit].self, forKey: .spiceSubcircuits) ?? [],
            pinNames: try container.decodeIfPresent([String].self, forKey: .pinNames) ?? [],
            cornerNames: try container.decodeIfPresent([String].self, forKey: .cornerNames) ?? [],
            timingArcCount: try container.decodeIfPresent(Int.self, forKey: .timingArcCount) ?? 0,
            timingRelatedPinNames: try container.decodeIfPresent([String].self, forKey: .timingRelatedPinNames) ?? [],
            timingTableValueCount: try container.decodeIfPresent(Int.self, forKey: .timingTableValueCount) ?? 0,
            libertyCells: try container.decodeIfPresent([PDKLibertyCell].self, forKey: .libertyCells) ?? [],
            libertyTimingArcs: try container.decodeIfPresent([PDKLibertyTimingArc].self, forKey: .libertyTimingArcs) ?? [],
            libertyTimingTables: try container.decodeIfPresent([PDKLibertyTimingTable].self, forKey: .libertyTimingTables) ?? [],
            unitDeclarations: try container.decodeIfPresent([String: String].self, forKey: .unitDeclarations) ?? [:],
            elementCount: try container.decodeIfPresent(Int.self, forKey: .elementCount) ?? 0,
            metadata: try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        )
    }

    private static func sortedUnique(_ values: [String]) -> [String] {
        Array(Set(values.filter { !$0.isEmpty })).sorted()
    }

    private enum CodingKeys: String, CodingKey {
        case format
        case source
        case sourceArtifact
        case libraryName
        case layerNames
        case physicalLayerNumbers
        case cellNames
        case viaNames
        case modelNames
        case modelTypes
        case modelParameterNames
        case spiceModels
        case spiceSubcircuits
        case pinNames
        case cornerNames
        case timingArcCount
        case timingRelatedPinNames
        case timingTableValueCount
        case libertyCells
        case libertyTimingArcs
        case libertyTimingTables
        case unitDeclarations
        case elementCount
        case metadata
    }
}
