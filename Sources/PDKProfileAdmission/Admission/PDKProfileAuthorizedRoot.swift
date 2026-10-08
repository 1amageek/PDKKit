import CircuiteFoundation
import Foundation

public struct PDKProfileAuthorizedRoot: Sendable {
    public let rootID: ArtifactRootID
    public let rootURL: URL
    internal let binding: String
    public init(rootID: ArtifactRootID, rootURL: URL) throws(PDKProfileAdmissionError) {
        guard rootURL.isFileURL, rootURL.baseURL == nil, rootURL.path.hasPrefix("/") else { throw .missingBinding }
        self.rootID = rootID; self.rootURL = rootURL; binding = rootURL.absoluteString
    }
}
