import CircuiteFoundation
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
import Foundation

/// Builds immutable artifact references for PDK resources.
public enum PDKArtifactReferenceBuilder {
    public static func artifactReference(
        for locator: ArtifactLocator,
        resolvedURL: URL? = nil
    ) throws -> ArtifactReference {
        guard let resolvedURL else {
            throw PDKArtifactReferenceError.invalidLocation(
                path: locator.path,
                reason: "A resolved URL is required to materialize an artifact locator."
            )
        }
        let materializedLocator = try materializedLocator(for: locator, resolvedURL: resolvedURL)
        return try LocalArtifactReferencer().reference(materializedLocator)
    }

    public static func materializedLocator(
        for locator: ArtifactLocator,
        resolvedURL: URL
    ) throws -> ArtifactLocator {
        ArtifactLocator(
            location: try ArtifactLocation(fileURL: resolvedURL),
            role: locator.role,
            kind: locator.kind,
            format: locator.format
        )
    }

    public static func artifactReference(
        for reference: ArtifactReference,
        resolvedURL: URL? = nil
    ) throws -> ArtifactReference {
        guard let resolvedURL else { return reference }
        _ = try ArtifactLocation(fileURL: resolvedURL)
        return reference
    }

    public static func artifactReference(
        kind: ArtifactKind,
        format: ArtifactFormat,
        digest: ContentDigest,
        byteCount: UInt64
    ) throws -> ArtifactReference {
        let canonicalKind = kind.rawValue.hasPrefix("pdk.")
            ? kind
            : try ArtifactKind(rawValue: "pdk.\(kind.rawValue.lowercased())")
        return try ArtifactReference(
            digest: digest,
            byteCount: byteCount,
            descriptor: ArtifactDescriptor(
                role: .input,
                kind: canonicalKind,
                format: try artifactFormat(for: format)
            )
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
