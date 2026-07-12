import Foundation

public enum PDKAssetRole: String, Sendable, Hashable, Codable, CaseIterable {
    case manifest
    case layerMap
    case technology
    case model
    case cell
    case ruleDeck
    case lef
    case gdsii
    case oasis
    case spice
    case liberty
    case corner
    case extraction
    case electromigration
    case reliability
    case other
}
