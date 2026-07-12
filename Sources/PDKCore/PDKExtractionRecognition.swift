import Foundation

public struct PDKExtractionRecognition: Sendable, Hashable, Codable {
    public var layerIDs: [String]
    public var markerNames: [String]
    public var extractorKeys: [String]

    public init(
        layerIDs: [String] = [],
        markerNames: [String] = [],
        extractorKeys: [String] = []
    ) {
        self.layerIDs = layerIDs
        self.markerNames = markerNames
        self.extractorKeys = extractorKeys
    }
}
