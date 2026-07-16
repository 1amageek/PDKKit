import CircuiteFoundation
import Foundation
import CircuiteFoundation

/// Converts PDK artifact locators into canonical Foundation artifact identities.
public enum PDKFoundationArtifactBridge {
    public static func artifactReference(
        for locator: ArtifactLocator,
        resolvedURL: URL? = nil
    ) throws -> ArtifactReference {
        guard let resolvedURL else {
            throw PDKFoundationArtifactError.invalidLocation(
                path: locator.path,
                reason: "A resolved URL is required to materialize an artifact locator."
            )
        }
        let location = try ArtifactLocation(fileURL: resolvedURL)
        let materializedLocator = ArtifactLocator(
            location: location,
            role: locator.role,
            kind: locator.kind,
            format: locator.format
        )
        return try LocalArtifactReferencer().reference(materializedLocator)
    }

    public static func artifactReference(
        for reference: ArtifactReference,
        resolvedURL: URL? = nil
    ) throws -> ArtifactReference {
        guard let resolvedURL else { return reference }
        let location = try ArtifactLocation(fileURL: resolvedURL)
        let locator = ArtifactLocator(
            location: location,
            role: reference.locator.role,
            kind: reference.kind,
            format: reference.format
        )
        return ArtifactReference(
            id: reference.id,
            locator: locator,
            digest: reference.digest,
            byteCount: reference.byteCount,
            producer: reference.producer
        )
    }

    public static func artifactReference(
        assetID: String,
        path: URL,
        kind: ArtifactKind,
        format: ArtifactFormat,
        digest: ContentDigest,
        byteCount: UInt64
    ) throws -> ArtifactReference {
        let location: ArtifactLocation
        do {
            location = try ArtifactLocation(fileURL: path)
        } catch {
            throw PDKFoundationArtifactError.invalidLocation(
                path: path.path,
                reason: error.localizedDescription
            )
        }
        let canonicalKind = kind.rawValue.hasPrefix("pdk.")
            ? kind
            : try ArtifactKind(rawValue: "pdk.\(kind.rawValue.lowercased())")
        return ArtifactReference(
            id: try ArtifactID(rawValue: assetID),
            locator: ArtifactLocator(
                location: location,
                role: .input,
                kind: canonicalKind,
                format: try artifactFormat(for: format)
            ),
            digest: digest,
            byteCount: byteCount
        )
    }

    public static func artifactFormat(
        for format: ArtifactFormat
    ) throws -> ArtifactFormat {
        switch format {
        case .spice:
            return .spice
        case .systemVerilog:
            return .systemVerilog
        case .verilog:
            return .verilog
        case .oasis:
            return .oasis
        case .gdsii:
            return .gdsii
        case .lef:
            return .lef
        case .def:
            return .def
        case .spef:
            return .spef
        case .dspf:
            return .dspf
        case .liberty:
            return .liberty
        case .sdf:
            return .sdf
        case .vcd:
            return .vcd
        case .json:
            return .json
        default:
            return try ArtifactFormat(
                rawValue: format.rawValue.lowercased().replacingOccurrences(of: "_", with: "-")
            )
        }
    }
}
