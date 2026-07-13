import CircuiteFoundation
import Foundation
import XcircuitePackage

public struct PDKArtifactURLResolver: Sendable {
    public init() {}

    public func resolve(
        _ reference: XcircuiteFileReference,
        baseDirectoryPath: String? = nil
    ) throws -> URL {
        let path = reference.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw PDKArtifactPathError.emptyPath
        }

        if path.hasPrefix("/") {
            do {
                return try ArtifactLocation(fileURL: URL(filePath: path)).resolvedFileURL()
            } catch {
                throw PDKArtifactPathError.pathEscapesBaseDirectory(path)
            }
        }

        guard let baseDirectoryPath else {
            return URL(filePath: path).standardizedFileURL
        }
        let basePath = baseDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !basePath.isEmpty, basePath.hasPrefix("/") else {
            throw PDKArtifactPathError.baseDirectoryNotAbsolute(baseDirectoryPath)
        }

        do {
            let baseURL = try ArtifactLocation(fileURL: URL(filePath: basePath))
                .resolvedFileURL()
            let relativeLocation = try ArtifactLocation(workspaceRelativePath: path)
            return try relativeLocation.resolvedFileURL(relativeTo: baseURL)
        } catch let error as ArtifactLocationError {
            switch error {
            case .outsideWorkspaceRoot:
                throw PDKArtifactPathError.pathEscapesBaseDirectory(path)
            default:
                throw PDKArtifactPathError.pathEscapesBaseDirectory(path)
            }
        } catch {
            throw PDKArtifactPathError.pathEscapesBaseDirectory(path)
        }
    }
}
