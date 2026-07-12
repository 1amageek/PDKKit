import Foundation

public enum PDKViewKind: String, Sendable, Hashable, Codable, CaseIterable {
    case layerMap
    case lef
    case gdsii
    case oasis
    case spice
    case liberty
    case ruleDeck
    case extraction
    case other
}
