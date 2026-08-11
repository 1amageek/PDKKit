import Foundation
import CircuiteFoundation
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation

struct TestArtifactBinding {
    let reference: ArtifactReference
    let locator: ArtifactLocator
}

func makeArtifactBinding(
    artifactID _: String = "artifact",
    path: String,
    kind: ArtifactKind,
    format: ArtifactFormat,
    sha256: String? = nil,
    byteCount: Int64? = nil,
    role: ArtifactRole = .input
) throws -> TestArtifactBinding {
    let digest = try ContentDigest(
        algorithm: .sha256,
        hexadecimalValue: sha256 ?? String(repeating: "0", count: 64)
    )
    let locator = ArtifactLocator(
            location: try makeArtifactLocation(path),
            role: role,
            kind: kind,
            format: format
        )
    return TestArtifactBinding(
        reference: try ArtifactReference(
            digest: digest,
            byteCount: UInt64(max(0, byteCount ?? 0)),
            descriptor: ArtifactDescriptor(role: role, kind: kind, format: format)
        ),
        locator: locator
    )
}

func makeArtifactLocator(
    path: String,
    kind: ArtifactKind,
    format: ArtifactFormat,
    role: ArtifactRole = .input
) throws -> ArtifactLocator {
    ArtifactLocator(
        location: try makeArtifactLocation(path),
        role: role,
        kind: kind,
        format: format
    )
}

private func makeArtifactLocation(_ path: String) throws -> ArtifactLocation {
    if path.hasPrefix("/") {
        return try ArtifactLocation(fileURL: URL(filePath: path))
    }
    return try ArtifactLocation(workspaceRelativePath: path)
}
