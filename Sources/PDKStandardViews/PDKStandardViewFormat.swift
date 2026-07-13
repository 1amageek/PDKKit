import Foundation
import PDKCore
import CircuiteFoundation

public enum PDKStandardViewFormat: String, Sendable, Hashable, Codable, CaseIterable {
    case lef
    case gdsii
    case oasis
    case spice
    case liberty

    public var fileFormat: ArtifactFormat {
        switch self {
        case .lef: .lef
        case .gdsii: .gdsii
        case .oasis: .oasis
        case .spice: .spice
        case .liberty: .liberty
        }
    }

    public var manifestView: PDKViewKind {
        switch self {
        case .lef: .lef
        case .gdsii: .gdsii
        case .oasis: .oasis
        case .spice: .spice
        case .liberty: .liberty
        }
    }
}
