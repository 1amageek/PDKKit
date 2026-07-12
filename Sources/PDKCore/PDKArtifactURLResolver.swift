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
            return URL(filePath: path).standardizedFileURL
        }

        guard let baseDirectoryPath else {
            return URL(filePath: path).standardizedFileURL
        }
        let basePath = baseDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !basePath.isEmpty, basePath.hasPrefix("/") else {
            throw PDKArtifactPathError.baseDirectoryNotAbsolute(baseDirectoryPath)
        }

        let baseURL = URL(filePath: basePath).standardizedFileURL
        let resolvedURL = baseURL.appending(path: path).standardizedFileURL
        guard isContained(resolvedURL, in: baseURL) else {
            throw PDKArtifactPathError.pathEscapesBaseDirectory(path)
        }
        return resolvedURL
    }

    private func isContained(_ url: URL, in base: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        let basePath = base.path(percentEncoded: false)
        return path == basePath || path.hasPrefix(basePath.hasSuffix("/") ? basePath : "\(basePath)/")
    }
}
