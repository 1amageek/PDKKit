import Foundation

enum PDKMaskProjectionError: Error, Equatable, Sendable, LocalizedError {
    case unboundViaMaster(String)

    var errorDescription: String? {
        switch self {
        case .unboundViaMaster(let name):
            "Standard-view inspection cannot inventory via '\(name)' without resolved master material layers."
        }
    }
}
