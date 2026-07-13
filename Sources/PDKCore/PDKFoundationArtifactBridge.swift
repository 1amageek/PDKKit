@_exported import CircuiteFoundation
import Foundation
import XcircuitePackage

/// Converts the retained Xcircuite compatibility reference into the canonical
/// CircuiteFoundation artifact identity used by PDK validation.
public enum PDKFoundationArtifactBridge {
    public static func artifactReference(
        for reference: XcircuiteFileReference,
        resolvedURL: URL? = nil
    ) throws -> ArtifactReference {
        guard let hexadecimalValue = reference.sha256, !hexadecimalValue.isEmpty else {
            throw PDKFoundationArtifactError.missingDigest(path: reference.path)
        }
        guard let byteCount = reference.byteCount else {
            throw PDKFoundationArtifactError.missingByteCount(path: reference.path)
        }
        guard byteCount >= 0 else {
            throw PDKFoundationArtifactError.invalidByteCount(path: reference.path)
        }

        let location: ArtifactLocation
        do {
            location = try makeLocation(for: reference.path, resolvedURL: resolvedURL)
        } catch {
            throw PDKFoundationArtifactError.invalidLocation(
                path: reference.path,
                reason: error.localizedDescription
            )
        }

        let digest: ContentDigest
        do {
            digest = try ContentDigest(
                algorithm: .sha256,
                hexadecimalValue: hexadecimalValue
            )
        } catch {
            throw PDKFoundationArtifactError.malformedDigest(
                path: reference.path,
                reason: error.localizedDescription
            )
        }

        let artifactID: ArtifactID
        if let rawArtifactID = reference.artifactID, !rawArtifactID.isEmpty {
            do {
                artifactID = try ArtifactID(rawValue: rawArtifactID)
            } catch {
                throw PDKFoundationArtifactError.invalidLocation(
                    path: reference.path,
                    reason: error.localizedDescription
                )
            }
        } else {
            artifactID = ArtifactID(
                stableKey: "pdk:\(location.storage.rawValue):\(location.value):\(reference.kind.rawValue):\(reference.format.rawValue)"
            )
        }

        return ArtifactReference(
            id: artifactID,
            locator: ArtifactLocator(
                location: location,
                kind: try ArtifactKind(rawValue: "pdk.\(reference.kind.rawValue.lowercased())"),
                format: try artifactFormat(for: reference.format)
            ),
            digest: digest,
            byteCount: UInt64(byteCount)
        )
    }

    public static func artifactReference(
        assetID: String,
        path: URL,
        kind: XcircuiteFileKind,
        format: XcircuiteFileFormat,
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
        return ArtifactReference(
            id: try ArtifactID(rawValue: assetID),
            locator: ArtifactLocator(
                location: location,
                kind: try ArtifactKind(rawValue: "pdk.\(kind.rawValue.lowercased())"),
                format: try artifactFormat(for: format)
            ),
            digest: digest,
            byteCount: byteCount
        )
    }

    private static func makeLocation(
        for path: String,
        resolvedURL: URL?
    ) throws -> ArtifactLocation {
        if let resolvedURL {
            return try ArtifactLocation(fileURL: resolvedURL)
        }
        if path.hasPrefix("/") {
            return try ArtifactLocation(fileURL: URL(filePath: path))
        }
        return try ArtifactLocation(workspaceRelativePath: path)
    }

    public static func artifactFormat(
        for format: XcircuiteFileFormat
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
