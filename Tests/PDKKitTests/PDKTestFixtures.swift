import Foundation

enum PDKTestFixtures {
    static let rootURL: URL = {
        guard let resourceURL = Bundle.module.resourceURL else {
            preconditionFailure("PDKKit test resource bundle is unavailable.")
        }
        let rootURL = resourceURL.appending(path: "Fixtures", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: rootURL.path(percentEncoded: false)) else {
            preconditionFailure("PDKKit test fixture directory is unavailable.")
        }
        return rootURL
    }()

    static let validPDKURL = rootURL.appending(path: "valid-pdk", directoryHint: .isDirectory)
}
