import Foundation

public enum PDKLayerPurpose: String, Sendable, Hashable, Codable, CaseIterable {
    case drawing
    case pin
    case label
    case blockage
    case implant
    case diffusion
    case well
    case poly
    case contact
    case metal
    case via
    case marker
    case other
}
